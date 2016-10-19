#!/usr/bin/env bash
# Download the base Ubuntu image and unzip it
BASE_IMAGE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.1-base-amd64.tar.gz
BASE_IMAGE=./ubuntu-base-16.04.1-base-amd64.tar.gz
IMAGE_NAME=spotweb-latest-ubuntu-amd64

NL=$'\n'

ACB="acbuild --debug"

if [ ! -e "./$BASE_IMAGE"  ]; then
  wget "$BASE_IMAGE_URL"
fi

# Begin the build with the base ubuntu image
$ACB begin "$BASE_IMAGE"

# If we exit before completion, clean up
trap "{ export EXT=$?; $ACB end && exit $EXT; }" SIGINT SIGTERM

# Configure the container
$ACB set-name "$IMAGE_NAME"
$ACB mount add config /spotweb-config/
$ACB mount add run /run/php/
$ACB mount add www /spotweb/

# Update sources.list
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates universe"

# Install Sonarr
$ACB run -- apt update
$ACB run -- apt upgrade -y
$ACB run -- apt install git php-fpm php-mysql  -y

# Setup spotweb
$ACB run -- mkdir /spotweb-config
$ACB run -- mkdir /spotweb-cache
$ACB run -- git clone https://github.com/spotweb/spotweb.git

$ACB run -- rm -rf /var/www/html
$ACB run -- ln -s /var/www/html /spotweb
$ACB run -- ln -s /spotweb-config/ownsettings.php /spotweb/ownsettings.php

# Set executable
$ACB set-exec -- /usr/sbin/php-fpm7.0 -F --fpm-config /etc/php/7.0/fpm/php-fpm.conf

# Write out the ACI
$ACB write --overwrite "$IMAGE_NAME".aci

# Done
$ACB end
