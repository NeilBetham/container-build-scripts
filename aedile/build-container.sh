#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/eb898e26722d61d3a16a156c9a89a6908624cdf5/bookworm/slim/rootfs.tar.xz"
BASE_IMAGE_FILE="../debian-base-image.tar.gz"
IMAGE_NAME="aedilebot-latest-debian-amd64"
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
$BR -- apt install gnupg2 ca-certificates curl -y

# Copy CAs to container
echo_step "Loading CAs"
buildah add ${CTNR} ../cas/* /usr/local/share/ca_certificates

# Install Aedile
echo_step "Installing Aedilebot"
$BR -- apt install git python3 python3-pip python3-venv -y
$BR -- curl -L https://github.com/olted/aedilebot/archive/refs/heads/main.tar.gz -o main.tar.gz
$BR -- tar -xvzf main.tar.gz
$BR -- rm main.tar.gz
$BR -- python3 -m venv /aedilebot-main/
$BR -- /aedilebot-main/bin/pip3 install -r aedilebot-main/requirements.txt

# Configure the container for Jellyfin
echo_step "Configuring Container"
buildah config --workingdir /aedilebot-main ${CTNR}
buildah config --cmd "/aedilebot-main/bin/python3 /aedilebot-main/src/main.py" ${CTNR}

# Commit the container
echo_step "Committing Container"
buildah commit ${CTNR} "aedilebot"
