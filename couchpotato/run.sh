#!/usr/bin/env bash
rkt run \
  --volume app-data,kind=host,source=/tmp/couch/data \
  --volume downloads,kind=host,source=/tmp/couch/downloads \
  --volume media-directory,kind=host,source=/tmp/couch/movies/ \
  --port=http:9999 \
  --insecure-options=image \
  ./couchpotato-latest-ubuntu-amd64.aci 

