#!/usr/bin/env bash
# Download the base Ubuntu image and unzip it
BASE_IMAGE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.1-base-amd64.tar.gz
BASE_IMAGE=../ubuntu-base-16.04.1-base-amd64.tar.gz
IMAGE_NAME=nzbget-latest-ubuntu-amd64

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
$ACB mount add config /nzbget-config
$ACB mount add downloads /downloads
$ACB port add http tcp 6789

# Add multiverse packages for unrar
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial multiverse"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial multiverse"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates multiverse"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates multiverse"

# Update the image
$ACB run -- apt update
$ACB run -- apt upgrade -y
$ACB run -- apt install wget unrar -y

# Install NZBGet
$ACB run -- mkdir /nzbget
$ACB run -- mkdir /downloads/
$ACB run -- mkdir /nzbget-config/

## Download and install
NZBGET_RELEASE_URL=$(wget -O - http://nzbget.net/info/nzbget-version-linux.json | sed -n "s/^.*stable-download.*: \"\(.*\)\".*/\1/p")
$ACB run -- wget --no-check-certificate -O /nzbget/nzbget-latest-bin-linux.run "$NZBGET_RELEASE_URL" 
$ACB run -- sh /nzbget/nzbget-latest-bin-linux.run

## Move config so we can link but expose it for reference if need be
$ACB run -- mv /nzbget/nzbget.conf /nzbget/nzbget.conf.orig
$ACB run -- ln -s /nzbget-config/nzbget.conf /nzbget/nzbget.conf
$ACB run -- ln -s /nzbget/nzbget.conf.orig /nzbget-config/nzbget.conf.orig

# Set executable
$ACB set-exec -- /nzbget/nzbget -c /nzbget/nzbget.conf -s -o outputmode=log

# Write out the ACI
$ACB write --overwrite "$IMAGE_NAME".aci

# Done
$ACB end
