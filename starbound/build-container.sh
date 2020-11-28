#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
IMAGE_NAME="starbound-latest-ubuntu-amd64"
TMP_DIR="/tmp/$(uuidgen)"
STEAM_CACHE="${SCRIPT_DIR}/steam_cache"
STEAM_USERNAME_CACHE="${SCRIPT_DIR}/steam_user"

source ../utils.sh

# Setup tmp / cache dirs
mkdir "${TMP_DIR}"
if [ ! -d "${STEAM_CACHE}" ]; then
  mkdir "${STEAM_CACHE}"
fi

# Get steam username
if [ ! -f "${STEAM_USERNAME_CACHE}" ]; then
  echo "Enter Steam username followed by enter:"
  read STEAM_USERNAME
  echo "${STEAM_USERNAME}" > ${STEAM_USERNAME_CACHE}
  NEEDS_LOGIN=true
else
  STEAM_USERNAME="$(cat ${STEAM_USERNAME_CACHE})"
  NEEDS_LOGIN=false
fi

# Download base image
if [ ! -f "${BASE_IMAGE_FILE}" ]; then
curl -L -o "${BASE_IMAGE_FILE}" "${BASE_IMAGE_URL}"
fi

# Setup the base container from tarball
CTNR=$(buildah from scratch)
BR="buildah run ${CTNR}"

# Import base image
buildah add ${CTNR} ${BASE_IMAGE_FILE} /

# Update base image
echo_step "Updating Base Image"
$BR -- apt update
$BR -- apt upgrade -y
$BR -- apt install lib32gcc1 curl libvorbisfile3 -y

# Install steamcmd
echo_step "Installing steamcmd"
$BR -- mkdir /steam/
$BR -- bash -c 'curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -C /steam -zxvf -'


# Install Starbound server binary
echo_step "Installing starbound server"
$BR -- mkdir /starbound

if [ "${NEEDS_LOGIN}" = true ]; then
echo_step "Login to Steam using the login command"
sleep 1
buildah run --mount type=bind,src=${STEAM_CACHE},target=/root/Steam --terminal ${CTNR} -- /steam/steamcmd.sh
fi

buildah run --mount type=bind,src=${STEAM_CACHE},target=/root/Steam ${CTNR} -- /steam/steamcmd.sh +login ${STEAM_USERNAME} +force_install_dir /starbound +app_update 211820 +quit

echo_step "Setting container info"
buildah config --cmd "/starbound/linux/starbound_server" ${CTNR}
buildah config --port 21025 ${CTNR}
buildah config --volume /starbound/storage ${CTNR}
buildah config --workingdir /starbound/linux ${CTNR}
echo "Done"

echo_step "Commiting container"
buildah commit ${CTNR} "starbound"
