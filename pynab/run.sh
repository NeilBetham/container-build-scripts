#!/usr/bin/env bash
rkt run \
  --volume config,kind=host,source=/opt/pynab/config \
  --volume logs,kind=host,source=/opt/pynab/logs \
  --volume run,kind=host,source=/opt/pynab/run \
  --volume pg-run,kind=host,source=/var/run/postgresql \
  --net=host \
  --interactive \
  --insecure-options=image \
  ./pynab-latest-ubuntu-amd64.aci

