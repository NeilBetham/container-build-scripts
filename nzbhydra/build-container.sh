#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/eb898e26722d61d3a16a156c9a89a6908624cdf5/bookworm/slim/rootfs.tar.xz"
BASE_IMAGE_FILE="../debian-base-image.tar.gz"
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
$BR -- apt install -y curl unzip python3 openjdk-17-jre-headless

# Install NZBHydra
echo_step "Installing NZBHydra"
$BR -- curl -L -o /tmp/nzbhydra2.zip $(curl -s $(curl -s https://api.github.com/repos/theotherp/nzbhydra2/releases/latest | grep assets_url | cut -d\" -f4) | grep 'amd64-linux.zip' | grep browser_download_url | cut -d\" -f 4)
$BR -- mkdir /nzbhydra2
$BR -- unzip /tmp/nzbhydra2.zip -d /nzbhydra2
$BR -- rm /tmp/nzbhydra2.zip
$BR -- chmod +x /nzbhydra2/nzbhydra2
$BR -- chmod +x /nzbhydra2/nzbhydra2wrapperPy3.py

# Configure the container
echo_step "Configuring Container"
buildah config --entrypoint '["/nzbhydra2/nzbhydra2wrapperPy3.py", "--nobrowser", "--datafolder", "/data"]' ${CTNR}
buildah config --volume /data ${CTNR}
buildah config --port 5076 ${CTNR}

# Commit the container
echo_step "Commiting Container"
buildah commit ${CTNR} "nzbhydra2"
