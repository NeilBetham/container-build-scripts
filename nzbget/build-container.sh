#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
IMAGE_NAME="nzbget-latest-ubuntu-amd64"
TMP_DIR="/tmp/$(uuidgen)"

source ../utils.sh

# Setup tmp dir
mkdir "${TMP_DIR}"

# Download base image
if [ ! -f "${BASE_IMAGE_FILE}" ]; then
curl -L -o "${BASE_IMAGE_FILE}" "${BASE_IMAGE_URL}"
fi

# Setup the base container from tarball
CTNR=$(buildah from scratch)
echo_step "Building Container With ID: ${CTNR}"
BR="buildah run ${CTNR}"

# Import base image
buildah add ${CTNR} ${BASE_IMAGE_FILE} /

# Update base image
echo_step "Updating Base Image"
$BR -- apt update
$BR -- apt upgrade -y

# Install deps
echo_step "Installing Deps"
$BR -- apt install wget unrar -y

# Install nzbget
echo_step "Installing NZBGet"
$BR -- mkdir /nzbget
$BR -- mkdir /downloads
$BR -- mkdir /nzbget-config

# Download the latest release
NZBGET_RELEASE_URL=$(wget -O - http://nzbget.net/info/nzbget-version-linux.json | sed -n "s/^.*stable-download.*: \"\(.*\)\".*/\1/p")
$BR -- wget --no-check-certificate -O /nzbget/nzbget-latest-bin-linux.run "$NZBGET_RELEASE_URL"
$BR -- sh /nzbget/nzbget-latest-bin-linux.run

# Move config so we can link but expose it for reference if need be
$BR -- mv /nzbget/nzbget.conf /nzbget/nzbget.conf.orig
$BR -- ln -s /nzbget-config/nzbget.conf /nzbget/nzbget.conf
$BR -- ln -s /nzbget/nzbget.conf.orig /nzbget-config/nzbget.conf.orig

# Configure the container
echo_step "Configuring Container"
buildah config --cmd '/nzbget/nzbget -c /nzbget/nzbget.conf -s -o outputmode=log' ${CTNR}
buildah config --volume /downloads ${CTNR}
buildah config --volume /nzbget-config ${CTNR}
buildah config --port 6789 ${CTNR}

# Commit the container
echo_step "Commiting Container"
buildah commit ${CTNR} "nzbget"
