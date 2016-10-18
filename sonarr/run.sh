#!/usr/bin/env bash
rkt run \
  --volume app-data,kind=host,source=/tmp/sonarr/data \
  --volume downloads,kind=host,source=/tmp/sonarr/downloads \
  --volume media-directory,kind=host,source=/tmp/sonarr/tv/ \
  --volume rtc,kind=host,source=/dev/rtc \
  --port=http:9999 \
  --interactive \
  --insecure-options=image \
  ./sonarr-latest-ubuntu-amd64.aci --exec /bin/bash

