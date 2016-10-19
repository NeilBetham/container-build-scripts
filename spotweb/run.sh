#!/usr/bin/env bash
rkt run \
  --volume config,kind=host,source=/tmp/spotweb/config \
  --volume www,kind=host,source=/tmp/spotweb/cache \
  --volume run,kind=host,source=/tmp/spotweb/run/ \
  --insecure-options=image \
  --interactive \
  ./spotweb-latest-ubuntu-amd64.aci

