#!/usr/bin/env bash
# Download the base Ubuntu image and unzip it
BASE_IMAGE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.1-base-amd64.tar.gz
BASE_IMAGE=../ubuntu-base-16.04.1-base-amd64.tar.gz
IMAGE_NAME=couchpotato-latest-ubuntu-amd64

NL=$'\n'

ACB="acbuild --debug"

if [ ! -e "./$BASE_IMAGE"  ]; then
  cd ..
  wget "$BASE_IMAGE_URL"
  cd -
fi

# Begin the build with the base ubuntu image
$ACB begin "$BASE_IMAGE"

# If we exit before completion, clean up
trap "{ export EXT=$?; $ACB end && exit $EXT; }" SIGINT SIGTERM

# Configure the container
$ACB set-name "$IMAGE_NAME"
$ACB mount add app-data /couchpotato-data
$ACB mount add downloads /downloads
$ACB mount add media-directory /couchpotato-media
$ACB port add http tcp 5050
$ACB set-working-directory /couchpotato/

# Copy CAs
$ACB copy-to-dir ../cas/* /usr/local/share/ca-certificates/

# Mkdirs
$ACB run -- mkdir /couchpotato-data
$ACB run -- mkdir /downloads
$ACB run -- mkdir /couchpotato-media


# Update sources.list
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates universe"

# Install deps
$ACB run -- apt update
$ACB run -- apt upgrade -y
$ACB run -- apt install -y python-pip build-essential libssl-dev libffi-dev python-dev git
$ACB run -- pip install --upgrade pip
$ACB run -- pip install --upgrade pyopenssl

# Clone code
$ACB run -- mkdir /couchpotato/
$ACB run -- git clone https://github.com/CouchPotato/CouchPotatoServer.git /couchpotato/

# Set executable
$ACB set-exec -- python /couchpotato/CouchPotato.py --data_dir="/couchpotato-data/"

# Write out the ACI
$ACB write --overwrite "$IMAGE_NAME".aci

# Done
$ACB end
