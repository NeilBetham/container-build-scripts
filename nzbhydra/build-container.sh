#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
IMAGE_NAME="nzbhydra-latest-ubuntu-amd64"
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
buildah config --env DEBIAN_FRONTEND=noninteractive ${CTNR}

# Update base image
echo_step "Updating Base Image"
$BR -- apt update
$BR -- apt upgrade -y

# Install deps
echo_step "Installing Deps"
$BR -- apt install --no-install-recommends --no-install-suggests openjdk-11-jre-headless curl unzip -y

# Install NZBHydra
$BR -- curl -L -o /tmp/nzbhydra2.zip $(curl -s $(curl -s https://api.github.com/repos/theotherp/nzbhydra2/releases/latest | grep assets_url | cut -d\" -f4) | grep linux.zip | grep browser_download_url | cut -d\" -f 4)
$BR -- mkdir /nzbhydra2
$BR -- unzip /tmp/nzbhydra2.zip -d /nzbhydra2
$BR -- chmod +x /nzbhydra2/nzbhydra2

# Configure the container
echo_step "Configuring Container"
buildah config --entrypoint '["/nzbhydra2/nzbhydra2", "--nobrowser", "--datafolder", "/data"]' ${CTNR}
buildah config --volume /data ${CTNR}
buildah config --port 5076 ${CTNR}

# Commit the container
echo_step "Commiting Container"
buildah commit ${CTNR} "nzbhydra2"
