#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
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
$BR -- groupadd sonarr
$BR -- apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8
$BR -- tee /etc/apt/sources.list.d/sonarr.list <<< "deb http://apt.sonarr.tv/ubuntu bionic main"
$BR -- apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
$BR -- tee /etc/apt/sources.list.d/mono-official-stable.list <<< "deb https://download.mono-project.com/repo/ubuntu stable-bionic main"
$BR -- curl -o /tmp/mediainfo.deb https://mediaarea.net/repo/deb/repo-mediaarea_1.0-13_all.deb
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
