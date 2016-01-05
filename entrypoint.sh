#!/bin/bash

if [ "$CRON_ENV_FILE" ]
then
  printenv -0 | while read -d $'\0' V
  do
    echo -E "export \"${V//\"/\\\"}\""
  done > $CRON_ENV_FILE
fi

[ $TZ ] && echo $TZ > /etc/timezone

crontab -u ${CRON_OWNER:=$(whoami)} - <<< "$CRON_TAB"

exec "${@}"
