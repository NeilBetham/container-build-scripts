#!/usr/bin/env bash
SCRIPT_DIR="$(dirname $(readlink -f $0))"
BASE_IMAGE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.5-base-amd64.tar.gz"
BASE_IMAGE_FILE="../base-image.tar.gz"
IMAGE_NAME="spotweb-latest-ubuntu-amd64"
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
BR="buildah run ${CTNR}"

# Import base image
buildah add ${CTNR} ${BASE_IMAGE_FILE} /

# Update base image
echo_step "Updating Base Image"
$BR -- apt update
$BR -- apt upgrade -y
$BR -- apt install lib32gcc1 curl libvorbisfile3 -y

# Install deps
echo_step "Installing deps"
$BR -- /bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt install supervisor git php-fpm php-mysql nginx php-gd php-curl php-zip php-xml php-mbstring -y'


echo_step "Writing configs"
# Setup nginx
$BR -- tee /etc/nginx/sites-available/default <<< "${NGINX_SITE_CONFIG}"

# Write out supervisor config
$BR -- tee /etc/supervisor/conf.d/spotweb.conf <<< "${SUP_CONFIG}"
$BR -- tee /php-fpm-bootstrap.sh <<< "${FPM_BOOTSTRAP}"
$BR -- chmod +x /php-fpm-bootstrap.sh
$BR -- tee /ngx-bootstrap.sh <<< "${NGX_BOOTSTRAP}"
$BR -- chmod +x /ngx-bootstrap.sh

# PHP FPM config
$BR -- tee /etc/php/7.2/fpm/php.ini <<< "date.timezone=\"America/Los_Angeles\""

# Setup spotweb
echo_step "Setting up Spotweb"
$BR -- mkdir -p /run/php/
$BR -- mkdir /spotweb-config
$BR -- mkdir /spotweb-cache
$BR -- git clone https://github.com/spotweb/spotweb.git

$BR -- rm -rf /var/www/html
$BR -- ln -s /spotweb-config/ownsettings.php /spotweb/ownsettings.php
$BR -- ln -s /spotweb-config/dbsettings.inc.php /spotweb/dbsettings.inc.php
$BR -- ln -s /spotweb-cache/ /spotweb/cache

echo_step "Configuring container"
buildah config --cmd "/usr/bin/supervisord -n" ${CTNR}
buildah config --port 80 ${CTNR}
buildah config --workingdir /spotweb ${CTNR}
buildah config --volume /spotweb-config/ ${CTNR}
buildah config --volume /spotweb-run/ ${CTNR}
buildah config --volume /spotweb-logs/ ${CTNR}
buildah config --volume /spotweb-cache/ ${CTNR}
buildah config --volume /var/run/mysqld/ ${CTNR}

echo_step "Commiting container"
buildah commit ${CTNR} "spotweb"
