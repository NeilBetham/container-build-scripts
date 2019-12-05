#!/usr/bin/env bash

BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.3-base-amd64.tar.gz"
BASE_IMAGE_FILE="../ubuntu-base-18.04.3-base-amd64.tar.gz"
IMAGE_NAME="starbound-latest-ubuntu-amd64"
TMP_DIR="/tmp/$(uuidgen)"

# Setup tmpdir
mkdir "${TMP_DIR}"

# Download base image
if [ ! -f "${BASE_IMAGE_FILE}" ]; then
curl -L -o "${BASE_IMAGE_FILE}" "${BASE_IMAGE_URL}"
fi

# Setup the base container from tarball
CTNR=$(buildah from scratch)

# Import base image
buildah add ${CTNR} ${BASE_IMAGE_FILE} /

# Update base image
echo "=================================================="
echo "Updating Base Image"
echo "=================================================="
buildah run ${CTNR} -- apt update
buildah run ${CTNR} -- apt upgrade -y

# Install steamcmd
echo "=================================================="
echo "Installing steamcmd"
echo "=================================================="
buildah run ${CTNR} -- dpkg --add-architecture i386
buildah run ${CTNR} -- apt update

FIFO="${TMP_DIR}/install_pipe"
mkfifo "${FIFO}"
buildah run ${CTNR} -- bash -vxc "apt install steamcmd -y" < ${FIFO} &
JOB_PID=$!
while kill -0 "${JOB_PID}" 2>/dev/null; do
  echo '2' >${FIFO};
  sleep 1
done

# Install Starbound server binary
echo "=================================================="
echo "Installing Starbound Server"
echo "=================================================="

buildah run ${CTNR} -- mkdir -p "/usr/lib/games/steam/linux32/"
buildah run ${CTNR} -- ln -s /usr/lib/games/steam/steamcmd /usr/lib/games/steam/linux32
buildah run ${CTNR} -- mkdir /starbound
buildah run ${CTNR} -- bash -c '/usr/lib/games/steam/steamcmd.sh +login anonymous +force_install_dir /starbound +app_update 533830 +quit || true'
buildah run ${CTNR} -- ls /starbound
buildah run ${CTNR} -- ls -R /usr/lib/games/steam/
buildah run ${CTNR} -- ls -R /root
