#!/usr/bin/env bash

function echo_step {
  MESSAGE="$1"
  CHARACTERS=$(expr $(echo "${MESSAGE}" | wc -m) - 1)
  SEP_LENGTH=$(( 80 > ${CHARACTERS} ? 80 : ${CHARACTERS}))
  SEPS=$(printf '%*s' "${SEP_LENGTH}" | tr ' ' "=")
  MESSAGE_OFFSET=$(( (${SEP_LENGTH} / 2) - (${CHARACTERS} / 2) ))
  OFFSET=$(printf '%*s' "${MESSAGE_OFFSET}")
  echo "${SEPS}"
  echo "${OFFSET}${MESSAGE}"
  echo "${SEPS}"
}
