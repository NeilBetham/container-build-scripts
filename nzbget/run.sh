#!/usr/bin/env bash
rkt run \
  --volume config,kind=host,source=/tmp/nzbget/config \
  --volume downloads,kind=host,source=/tmp/nzbget/downloads \
  --port=http:9999 \
  --interactive \
  --insecure-options=image \
  ./nzbget-latest-ubuntu-amd64.aci

