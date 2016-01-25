A lightweight [cron] container, which allows crontabs to be specified using environment variables.

This allows for rapid prototyping and development of cron jobs, especially when using ```docker-compose```.

[cron]: https://www.debian-administration.org/article/56/Command_scheduling_with_cron

# Configuration

Configure the cron container using environment variables. Each environment variable named with the prefix ```CRON_D_``` is linked into ```/etc/cron.d/```, the filename of which will be the suffix of the environment variables name; e.g.

    docker run \
      -e 'CRON_D_HELLO_WORLD=* * * * * root echo Hello World from $(whoami) | logger' \
      nickbreen/cron

Will create a file ```/etc/cron.d/HELLO_WORLD```.

# Logging

cron jobs are not logged _per-se_. Instead, if an MTA is available, their output is emailed to the owner of the crontab. Otherwise, the job should explicitly pipe  ```stdout``` and ```stderr``` (with ```2>&1```) to ```logger```.

This example job ```echo```s the value of ```$HELLO_WORLD``` or exits with an error and message if it's undefined.

    docker run \
      -e 'HELLO_WORLD=Hello World!' \
      -e 'CRON_D_HELLO=* *    * * *    root . /etc/container_environment.sh; echo ${HELLO_WORLD:?variable not set} 2>&1 | logger' \
      nickbreen/cron

## Advanced Example

Include Apache Utils, s3cmd, and the MySQL client so the ```mysqldump```, ```htcacheclean``` and ```s3cmd``` commands are available.

    # Dockerfile
    FROM nickbreen/cron

    RUN DEBIAN_FRONTEND=noninteractive && \
      apt-get -q update && \
      apt-get -qy install mysql-client apache2-utils s3cmd && \
      apt-get -q clean

    # And so on ... setup a backup user, configure s3cmd, etc.


Note the escaped (```$$```) variables as ```docker-compose``` will (now) evaluate variables.

    # docker-compose.yml
    cron:
      build: .
      links:
        - mysqla
        - mysqlb
      volumes_from:
        - apache
      environment:
        CRON_D_CACHE: |
          # Every hour clean mod_cache_disk's cache.
          0 * * * * www-data htcacheclean -n -p/var/cache/apache2/mod_cache_disk 2>&1 | logger
        CRON_D_DB_BACKUPS: |
          # At 4am: dump MySQL DB's "A" and "B", compress, and upload to S3.
          0 4 * * * backup . /etc/container_environment; mysqldump -h$$MYSQLA_PORT_3306_TCP_ADDR -P$$MYSQLA_PORT_3306_TCP_PORT -u$$MYSQLA_ENV_MYSQL_USER -p$$MYSQLA_ENV_MYSQL_PASSWORD $$MYSQLA_ENV_MYSQL_DATABASE | gzip | s3cmd put - s3://bucketa/backup-$$MYSQLA_ENV_MYSQL_DATABASE.sql 2>&1 | logger
          0 4 * * * backup . /etc/container_environment; mysqldump -h$$MYSQLB_PORT_3306_TCP_ADDR -P$$MYSQLB_PORT_3306_TCP_PORT -u$$MYSQLB_ENV_MYSQL_USER -p$$MYSQLB_ENV_MYSQL_PASSWORD $$MYSQLB_ENV_MYSQL_DATABASE | gzip | s3cmd put - s3://bucketb/backup-$$MYSQLB_ENV_MYSQL_DATABASE.sql 2>&1 | logger
