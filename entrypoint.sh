#!/bin/bash

if [ $CRON_ENV_FILE ]
then
  # NUL delimit the vars; escape newlines and double-quotes, quote; NUL's back to NL's
  printenv -0 | sed -z -e '1i\set -a' -e 's/[\n\"]/\\\0/g;s/=/\0\"/;s/$/\"/' | tr '\0' '\n' > $CRON_ENV_FILE
fi

crontab -u ${CRON_OWNER:=$(whoami)} - <<< "$CRON_TAB"

exec "${@}"
