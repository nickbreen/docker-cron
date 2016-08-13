A lightweight [cron] container, which allows crontabs to be specified using
environment variables.

This allows for rapid prototyping and development of cron jobs, especially when
using `docker-compose`.

[cron]: https://www.debian-administration.org/article/56/Command_scheduling_with_cron

# Configuration

Configure the cron container using environment variables. Each environment
variable named with the prefix `CRON_D_` is linked into `/etc/cron.d/`,
the filename of which will be the environment variables name; e.g.

    docker run \
      -e "CRON_D_HELLO_WORLD=* * * * * root echo Hello World from \$(whoami) | logger\n" \
      nickbreen/cron

Will create a file `/etc/cron.d/CRON_D_HELLO_WORLD`.

# Logging

`cron` jobs are not logged _per-se_. Instead, if an MTA is available, their output
is emailed to the owner of the crontab. Otherwise, the job should explicitly
pipe  `stdout` and `stderr` (with `2>&1`) to `logger`.

This example job `echo`s the value of `$HELLO_WORLD` or exits with an
error and message if it's undefined.

    docker run \
      -e 'HELLO_WORLD=Hello World!' \
      -e "CRON_D_HELLO=* *    * * *    root . /etc/container_environment.sh; echo \${HELLO_WORLD:?variable not set} 2>&1 | logger\n" \
      nickbreen/cron:v2.0.0
