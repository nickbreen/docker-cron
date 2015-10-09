FROM php:5.6-apache
# See https://github.com/docker-library/wordpress

MAINTAINER Nick Breen <nick@foobar.net.nz>

RUN a2enmod rewrite

# WP-CLI requires less when showing help, ignores $PAGER!
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
	&& apt-get install -qy \
        less \
        libpng12-dev \
        libjpeg-dev \
    && apt-get clean

# Install WP-CLI http://wp-cli.org
# Install Bash completion for WP-CLI
RUN PHAR=/usr/local/lib/php/wp-cli.phar &&\
    curl -sSfLo $PHAR https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar &&\
    chmod +x $PHAR &&\
    ln -s $PHAR /usr/local/bin/wp &&\
    curl -sSfLo /etc/bash_completion.d/wp-cli https://raw.githubusercontent.com/wp-cli/wp-cli/master/utils/wp-completion.bash

# Install [a] Docker PHP PECL install script
# Enable the PHP opcache extension
# Install the PECL OAuth extension
RUN PECL=/usr/local/bin/docker-php-pecl-install \
    && curl -sSfLo $PECL https://raw.githubusercontent.com/helderco/docker-php/master/template/bin/docker-php-pecl-install \
    && chmod +x $PECL \
    && docker-php-ext-enable opcache \
    && docker-php-pecl-install oauth \
    && docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr \
    && docker-php-ext-install gd \
    && docker-php-ext-install mysqli

VOLUME /var/www/html

COPY entrypoint.sh oauth.php /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"] 

