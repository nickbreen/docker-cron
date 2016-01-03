#!/bin/bash

set -e

WP=$(which wp)

# Dirty function alias for wp-cli
function wp {
	$WP --allow-root "$@"
}

# Juggle ENV VARS
echo MYSQL_ROOT_PASSWORD = ${MYSQL_ROOT_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
echo WP_DB_NAME = ${WP_DB_NAME:=$MYSQL_ENV_MYSQL_DATABASE}
echo WP_DB_USER = ${WP_DB_USER:=$MYSQL_ENV_MYSQL_USER}
echo WP_DB_PASSWORD = ${WP_DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
echo WP_DB_HOST = ${WP_DB_HOST:=$MYSQL_PORT_3306_TCP_ADDR}
echo WP_DB_PORT = ${WP_DB_PORT:=$MYSQL_PORT_3306_TCP_PORT}

# Installs themes or plugins from a list on STDIN.
#
# STDIN format each line: slug [URL]
# E.g.
#   hello-dolly
#   wordpress-importer
#   some-other-plugin http://some.other/plugin.zip
#
# Usage:
#   install_a plugin <<< "plugin_slug|plugin_url"
#   install_a theme <<-EOT
#     theme_slug1
#     http://theme_url2
#   EOT
#
function install_a {
	while read SLUG;
	do
		if [ "$SLUG" ]
		then
			wp $1 is-installed $SLUG || wp $1 install $SLUG --activate
		fi
	done
}

# Installs themes or plugins specified on STDIN hosted at BitBucket.
# Usage:
#   install_b plugin|theme <<< "REPO TAG"
#
# REPO is the account/repository.
# TAG is optionally any tag|branch|commitish
#
# Requires $BB_KEY and $BB_SECRET environment variables.
#
# Note that the ZIP contains a directory named for the project
# and the commit. E.g. owner-repo-commitish
#
# To update or replace a theme or plugin:
# 1. Install the new theme/plugin. E.g. owner-repo-commitish
# 2. Find the old directory with the matching prefix. E.g. owner-repo-commitish
# 3. Deactivate the old theme/plugin. E.g. wp theme deactivate owner-repo-commitish
# 4. Activate the new theme/plugin. E.g. wp theme activate owner-repo-commitish
#
function install_b {
	while read REPO TAG;
	do
		if [ "$REPO" ]
		then
			local URL="https://bitbucket.org/${REPO}/get/${TAG:-master}.zip"
			local ZIP="${REPO/\//-}-${TAG:-master}.zip"
			# TODO get tar.gz instead, normalise the root dir name to $SLUG
			#+ using tar --strip-component=1 -C $SLUG and then zip and install
			php /oauth.php -v --key "$BB_KEY" --secret "$BB_SECRET" --url $URL > $ZIP
			wp $1 install $ZIP --activate --force
		fi
	done
}

# Installs themes or plugins specified on STDIN hosted at GitHub.
# Usage:
#   install_g plugin|theme <<< "REPO TAG"
#
# REPO is the account/repository.
# TAG is optionally any tag|branch|commitish
#
function install_g {
	while read REPO TAG
	do
		if [ "$REPO" ]
		then
			# Get the tarball URL for the latest (or specified release)
			local URL=$(curl -sL "https://api.github.com/repos/${REPO}/releases/${TAG:-latest}" | jq -r '.tarball_url')
			# If no releases are available fail-back to a commitish
			${URL:=https://api.github.com/repos/${REPO}/tarball/${TAG:-master}}
			# Fetch the tarball, extract it and re-zip (store only) using the
			# canonicalised name. This assumes that the project name is the canonical
			# name for the theme or plugin! This may not actually be the case! If not
			# then we'll need to specify a SLUG.
			local TMP=$(mktemp -d)
			pushd $TMP
			TGZ=$(curl -sLJOw '$TMP/%{filename_effective}' $URL)
			mkdir -p ${REPO##*/}
			tar xzf $TGZ --strip-components 1 -C ${REPO##*/}
			zip -0rm ${REPO##*/}.zip ${REPO##*/}
			popd
			wp $1 install $TMP/${REPO##*/}.zip --force --activate
			rm -rf $TMP
		fi
	done
}

function install_core {
	# Setup the database
	php /db.php

	# Always download the lastest WP
	wp core download --locale="${WP_LOCALE}" || true

	# Configure the database
	# Assume that a DB has already been created
	# Skip the DB check as there isn't a mysql client available
	rm -f wp-config.php
	wp core config \
			--skip-check \
			--locale="${WP_LOCALE}" \
			--dbname="${WP_DB_NAME}" \
			--dbuser="${WP_DB_USER}" \
			--dbpass="${WP_DB_PASSWORD}" \
			--dbhost="${WP_DB_HOST}:${WP_DB_PORT}" \
			--dbprefix="${WP_DB_PREFIX}" \
			--extra-php <<< "${WP_EXTRA_PHP}"

	# Configure the Blog
	wp core is-installed || wp core install \
			--url="$WP_URL" \
			--title="$WP_TITLE" \
			--admin_user="$WP_ADMIN_USER" \
			--admin_password="$WP_ADMIN_PASSWORD" \
			--admin_email="$WP_ADMIN_EMAIL"
}

function install_themes {
	install_a theme <<< "$WP_THEMES"
	install_g theme <<< "$GH_THEMES"
	install_b theme <<< "$BB_THEMES"
}

function install_plugins {
	install_a plugin <<< "$WP_PLUGINS"
	install_g plugin <<< "$GH_PLUGINS"
	install_b plugin <<< "$BB_PLUGINS"
}

# Sets options as specified in STDIN.
# Expects format of OPTION_NAME JSON_STRING
function options {
	while read OPTION JSON;
	do
		if [ "$OPTION" -a "$JSON" ]
		then
			wp option set "$OPTION" "$JSON" --format=json
		fi
	done <<< "$WP_OPTIONS"
}

# Allows execution of arbitrary WP-CLI commands.
# I suppose this is either quite dangerous and makes most of
# the rest of this script redundant.
function wp_commands {
	while read CMD;
	do
		[ -z "$CMD" ] || wp $CMD
	done <<< "$WP_COMMANDS"
}

function import {
	wp plugin is-installed wordpress-importer || install_a plugin <<< "wordpress-importer"
	wp plugin activate wordpress-importer
	# wp option update siteurl "$WP_URL"
	# wp option update home "$WP_URL"
	echo 'Importing, this may take a *very* long time.'
	wp import $WP_IMPORT --authors=create --skip=image_resize --quiet "$@"
}

install_core
install_themes
install_plugins
options
wp core update \
	&& wp core update-db \
	&& wp theme update --all \
	&& wp plugin update --all
wp_commands

# Ensure proper ownership and permissions.
# 'nobody' owns the files,
chown -R nobody:www-data .
chmod -R g-w,o-rwx .
chmod -R g+w wp-content/uploads
