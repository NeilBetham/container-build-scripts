#!/usr/bin/env bash
# Download the base Ubuntu image and unzip it
BASE_IMAGE_URL=http://cdimage.ubuntu.com/ubuntu-base/releases/16.04/release/ubuntu-base-16.04.1-base-amd64.tar.gz
BASE_IMAGE=../ubuntu-base-16.04.1-base-amd64.tar.gz
IMAGE_NAME=sonarr-latest-ubuntu-amd64

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
$ACB mount add app-data /sonarr/config
$ACB mount add downloads /downloads
$ACB mount add media-directory /sonarr/media
$ACB mount add rtc /dev/rtc --read-only
$ACB port add http tcp 8989

# Update sources.list
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb http://archive.ubuntu.com/ubuntu/ xenial-updates universe"
$ACB run -- tee -a /etc/apt/sources.list <<< "${NL}deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates universe"

# Install Sonarr
$ACB run -- apt-key adv --keyserver keyserver.ubuntu.com --recv-keys FDA5DFFC
$ACB run -- tee /etc/apt/sources.list.d/sonarr.list <<< "deb http://apt.sonarr.tv/ master main"
$ACB run -- apt update
$ACB run -- apt upgrade -y
$ACB run -- apt install nzbdrone -y

# Set executable
$ACB set-exec -- mono /opt/NzbDrone/NzbDrone.exe --no-browser -data=/sonarr/config

# Write out the ACI
$ACB write --overwrite "$IMAGE_NAME".aci

# Done
$ACB end
