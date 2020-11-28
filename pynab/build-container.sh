#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
IMAGE_NAME="pynab-latest-ubuntu-amd64"
TMP_DIR="/tmp/$(uuidgen)"

source ../utils.sh
source config.sh

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

# Update base image
echo_step "Updating Base Image"
$BR -- apt update
$BR -- apt upgrade -y
$BR -- apt install gnupg2 ca-certificates curl -y

# Install deps
echo_step "Install Deps"
$BR -- apt install git python3 python3-setuptools python3-pip libxml2-dev libxslt-dev libyaml-dev postgresql-server-dev-10 supervisor unrar -y

# Setup pynab
echo_step "Setting Up pynab"
$BR -- mkdir /pynab
$BR -- mkdir /pynab-config
$BR -- git clone https://github.com/NeilBetham/pynab.git /pynab

$BR -- ln -s /pynab-config/config.py /pynab/config.py
$BR -- pip3 install -r /pynab/requirements.txt
$BR -- pip3 install uwsgi
$BR -- ln -fs /usr/local/bin/uwsgi /usr/bin/uwsgi

# Write out bootstrap script
$BR -- tee /bootstrap-pynab.sh <<< "${BOOTSTRAP_SCRIPT}"
$BR -- chmod +x /bootstrap-pynab.sh

# Write out the uWSGI ini
$BR -- mkdir -p /etc/uwsgi/apps-enabled/
$BR -- tee -a /etc/uwsgi/apps-enabled/pynab.ini <<< "${UWSGI_INI}"

# Write out supervisor config
$BR -- tee -a /etc/supervisor/conf.d/pynab.conf <<< "${SUP_CONFIG}"

# Configure container
echo_step "Configuring Container"
buildah config --cmd "/bootstrap-pynab.sh" ${CTNR}
buildah config --volume /pynab-config/ ${CTNR}
buildah config --volume /pynab-logs/ ${CTNR}
buildah config --volume /pynab-run/ ${CTNR}
buildah config --volume /var/run/postgresql/ ${CTNR}
buildah config --workingdir /pynab/ ${CTNR}

# Commit the container
echo_step "Commiting Container"
buildah commit ${CTNR} "pynab"
