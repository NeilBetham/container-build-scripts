#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="https://github.com/debuerreotype/docker-debian-artifacts/raw/1f1e36af44a355418661956f15e39f5b04b848b6/buster/slim/rootfs.tar.xz"
BASE_IMAGE_FILE="../debian-base-image.buster.tar.gz"
IMAGE_NAME="sonarr-latest-ubuntu-amd64"
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
echo_step "Installing Sonarr"
$BR -- useradd -r sonarr
$BR -- gpg -k
$BR -- gpg --keyserver hkp://keyserver.ubuntu.com:80 --no-default-keyring --keyring /usr/share/keyrings/sonarr.gpg --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
$BR -- bash -c 'echo "deb [signed-by=/usr/share/keyrings/sonarr.gpg] https://apt.sonarr.tv/debian buster main" | tee /etc/apt/sources.list.d/sonarr.list'
$BR -- curl -o /tmp/mediainfo.deb https://mediaarea.net/repo/deb/repo-mediaarea_1.0-24_all.deb
$BR -- dpkg -i /tmp/mediainfo.deb
$BR -- rm /tmp/mediainfo.deb
$BR -- apt update
$BR -- apt upgrade -y
$BR -- apt install --no-install-recommends --no-install-suggests sonarr -y

# Configure the container for sonarr
echo_step "Configuring Container"
buildah config --cmd "mono /usr/lib/sonarr/bin/Sonarr.exe --no-browser -data=/config" ${CTNR}
buildah config --volume /config ${CTNR}
buildah config --volume /downloads ${CTNR}
buildah config --volume /media ${CTNR}
buildah config --port 8989 ${CTNR}

# Commit the container
echo_step "Committing Container"
buildah commit ${CTNR} "sonarr"
