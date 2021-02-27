#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/20.04.2/release/ubuntu-base-20.04.1-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
IMAGE_NAME="valheim-latest-ubuntu-amd64"
TMP_DIR="/tmp/$(uuidgen)"
STEAM_CACHE="${SCRIPT_DIR}/steam_cache"
STEAM_USERNAME_CACHE="${SCRIPT_DIR}/steam_user"

source ../utils.sh
source ./config.sh

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
$BR -- apt install -y curl lib32gcc1 libvorbisfile3

# Install steamcmd
echo_step "Installing steamcmd"
$BR -- mkdir /steam/
$BR -- bash -c 'curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -C /steam -zxvf -'

# Install Valheim server binary
echo_step "Installing valheim server"
$BR -- mkdir /valheim
$BR -- mkdir /valheim/linux
$BR -- mkdir /valheim/storage
$BR -- /steam/steamcmd.sh +login anonymous +force_install_dir /valheim/linux +app_update 896660 validate +exit

echo_step "Setup bootstrap script"
read -rd '' BOOTSTRAP <<EOF
#!/bin/bash
export LD_LIBRARY_PATH=./linux64:\$LD_LIBRARY_PATH
export SteamAppId=892970

/valheim/linux/valheim_server.x86_64 -name ${SERVER_NAME} -port 2456 -nographics -batchmode -world ${SERVER_NAME} -password ${SERVER_PASSWORD} -savedir /valheim/storage
EOF
$BR -- tee /valheim/bootstrap.sh <<< "${BOOTSTRAP}"
$BR -- chmod +x /valheim/bootstrap.sh

echo_step "Setting container info"
buildah config --cmd "/valheim/bootstrap.sh" ${CTNR}
buildah config --port 2456 ${CTNR}
buildah config --port 2457 ${CTNR}
buildah config --port 2458 ${CTNR}
buildah config --volume /valheim/storage ${CTNR}
buildah config --workingdir /valheim/linux ${CTNR}
echo "Done"

echo_step "Commiting container"
buildah commit ${CTNR} "valheim"
