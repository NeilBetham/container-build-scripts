#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/eb898e26722d61d3a16a156c9a89a6908624cdf5/bookworm/slim/rootfs.tar.xz"
BASE_IMAGE_FILE="../debian-base-image.tar.gz"
IMAGE_NAME="nzbget-latest-debian-amd64"
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
$BR -- sed -i.bak 's/.*main$/& contrib non-free/g' /etc/apt/sources.list.d/debian.sources
$BR -- apt update
$BR -- apt install curl unrar ca-certificates -y

# Install nzbget
echo_step "Installing NZBGet"
$BR -- mkdir /nzbget
$BR -- mkdir /downloads
$BR -- mkdir /config

# Download the latest release
NZBGET_RELEASE_URL=$(curl -L 'http://nzbget.net/info/nzbget-version-linux.json' | sed -n "s/^.*stable-download.*: \"\(.*\)\".*/\1/p")
$BR -- curl -kL -o /nzbget/nzbget-latest-bin-linux.run "$NZBGET_RELEASE_URL"
$BR -- sh /nzbget/nzbget-latest-bin-linux.run

# Move config so we can link but expose it for reference if need be
$BR -- mv /nzbget/nzbget.conf /nzbget/nzbget.conf.orig
$BR -- ln -s /config/nzbget.conf /nzbget/nzbget.conf
$BR -- ln -s /nzbget/nzbget.conf.orig /config/nzbget.conf.orig

# Configure the container
echo_step "Configuring Container"
buildah config --cmd '/nzbget/nzbget -c /nzbget/nzbget.conf -s -o outputmode=log' ${CTNR}
buildah config --volume /downloads ${CTNR}
buildah config --volume /config ${CTNR}
buildah config --port 6789 ${CTNR}

# Commit the container
echo_step "Committing Container"
buildah commit ${CTNR} "nzbget"
