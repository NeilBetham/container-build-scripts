#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/eb898e26722d61d3a16a156c9a89a6908624cdf5/bookworm/slim/rootfs.tar.xz"
BASE_IMAGE_FILE="../debian-base-image.tar.gz"
IMAGE_NAME="vault-latest-debian-amd64"
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

# Install Vault
echo_step "Installing Vault"
$BR -- bash -c "curl -L https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
$BR -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" | tee /etc/apt/sources.list.d/hashicorp.list'
$BR -- apt update
$BR -- apt install vault

# Configure the container for Vault
echo_step "Configuring Container"
buildah config --cmd "/usr/bin/vault -config=/config/vault-config.hcl -non-interactive" ${CTNR}
buildah config --volume /data ${CTNR}
buildah config --volume /config ${CTNR}
buildah config --port 443 ${CTNR}

# Commit the container
echo_step "Committing Container"
buildah commit ${CTNR} "vault"
