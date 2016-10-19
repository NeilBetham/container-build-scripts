#!/usr/bin/env bash
rkt run \
  --volume config,kind=host,source=/tmp/spotweb/config \
  --volume logs,kind=host,source=/tmp/spotweb/logs \
  --volume run,kind=host,source=/tmp/spotweb/run \
  --volume my-run,kind=host,source=/var/run/mysqld \
  --volume cache,kind=host,source=/tmp/spotweb/cache \
  --insecure-options=image \
  --interactive \
  --net=host \
  ./spotweb-latest-ubuntu-amd64.aci
