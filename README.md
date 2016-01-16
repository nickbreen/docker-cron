A lightweight [cron] container, which allows crontabs to be specified using environment variables.

This allows for rapid prototyping and development of cron jobs, especially when using ```docker-compose```.

[cron]: https://www.debian-administration.org/article/56/Command_scheduling_with_cron

# Configuration

Configure the cron container using environment variables. For each environment variable named with a ```CRON_D_``` prefix the value will be written to a file in ```/etc/cron.d/```, the filename of which will be the lowercased suffix of the environment variables name; e.g.

    docker run -e 'CRON_D_HELLO_WORLD=* * * * * root echo Hello World from $(whoami) | logger' nickbreen/cron

Will create a file ```/etc/cron.d/hello_world```.

## Example: ```docker-compose.yml```

    # docker-compose.yml    
    cron:
      build: .
      links:
        - mysql-a:mysqla
        - mysql-b:mysqlb
      volumes_from:
        - apache:apache
      environment:
        CRON_D_CACHE: |-
          # Every hour clean mod_cache_disk's cache.
          0 * * * * www-data htcacheclean -n -p/var/cache/apache2/mod_cache_disk
        CRON_D_DB_BACKUP: |-
          # At 4am: dump MySQL DB's "A" and "B", compress, and upload to S3.
          0 4 * * * root . /etc/container_environment; mysqldump -h$$MYSQLA_PORT_3306_TCP_ADDR -P$$MYSQLA_PORT_3306_TCP_PORT -u$$MYSQLA_ENV_MYSQLA_USER -p$$MYSQLA_ENV_MYSQLA_PASSWORD $$MYSQLA_ENV_MYSQLA_DATABASE | gzip | s3cmd put - s3://bucketa/backup-$$MYSQLA_ENV_MYSQL_DATABASE.sql
          0 4 * * * root . /etc/container_environment; mysqldump -h$$MYSQLB_PORT_3306_TCP_ADDR -P$$MYSQLB_PORT_3306_TCP_PORT -u$$MYSQLB_ENV_MYSQLB_USER -p$$MYSQLB_ENV_MYSQLB_PASSWORD $$MYSQLB_ENV_MYSQLB_DATABASE | gzip | s3cmd put - s3://bucketb/backup-$$MYSQLB_ENV_MYSQL_DATABASE.sql

Note the escaped (```$$```) variables as ```docker-compose``` will (now) evaluate variables.

Note this image does not include Apache, s3cmd, or MySQL so the ```mysqldump```, ```htcacheclean``` and ```s3cmd``` commands are not actually available! One would need to extend this image thus:

    # Dockerfile
    FROM nickbreen/cron

    RUN DEBIAN_FRONTEND=noninteractive && \
      apt-get -q update && \
      apt-get -qy install mysql-client apache2-utils s3cmd && \
      apt-get -q clean

    # And so on ... configure s3cmd etc.

# Logging

cron jobs are not logged _per-se_. Instead, if an MTA is available, their output is emailed to the owner of the crontab. Otherwise, the job should explicitly pipe  output to ```logger```.

    cron:
      build: .
      environment:
        HELLO_WORLD: Hello World!
        CRON_TAB: |-
          * *    * * *    . /etc/container_environment.sh; echo $$HELLO_WORLD | logger
