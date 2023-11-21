#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/eb898e26722d61d3a16a156c9a89a6908624cdf5/bookworm/slim/rootfs.tar.xz"
BASE_IMAGE_FILE="../debian-base-image.tar.gz"
IMAGE_NAME="jellyfin-latest-debian-amd64"
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

# Install sonarr
echo_step "Installing Jellyfin"
$BR -- useradd -r jellyfin
$BR -- apt install curl gnupg
$BR -- mkdir -p /etc/apt/keyrings
$BR -- bash -c 'curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg'
VERSION_OS="$($BR -- awk -F'=' '/^ID=/{ print $NF }' /etc/os-release )"
VERSION_CODENAME="$($BR -- awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release )"
DPKG_ARCHITECTURE="$($BR -- dpkg --print-architecture)"
read -rd '' SOURCES_D <<EOF
Types: deb
URIs: https://repo.jellyfin.org/${VERSION_OS}
Suites: ${VERSION_CODENAME}
Components: main
Architectures: ${DPKG_ARCHITECTURE}
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
$BR -- tee /etc/apt/sources.list.d/jellyfin.sources <<< "${SOURCES_D}"
$BR -- apt update
$BR -- apt install -y --no-install-recommends  jellyfin

# Configure the container for Jellyfin
echo_step "Configuring Container"
buildah config --cmd "/opt/jellyfin/jellyfin/jellyin -d /data -C /cache -c /config -l /var/log" ${CTNR}
buildah config --volume /config ${CTNR}
buildah config --volume /cache ${CTNR}
buildah config --volume /data ${CTNR}
buildah config --volume /media ${CTNR}
buildah config --port 8989 ${CTNR}

# Commit the container
echo_step "Committing Container"
buildah commit ${CTNR} "jellyfin"
