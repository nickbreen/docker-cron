#!/bin/bash

function log {
  [ "$VERBOSE" ] && echo "$@"
}

# Installs themes or plugins from a list on STDIN.
#
# STDIN format each line: slug [URL]
# E.g.
#   hello-dolly
#   wordpress-importer
#   some-other-plugin http://some.other/plugin.zip
#
# Usage:
#   install_a plugin <<< "plugin_slug plugin_url"
#   install_a theme <<-EOT
#     theme_slug1
#     theme_slug2 http://theme_url2
#   EOT
#
function install_a {
  local A=$1
  while read SLUG URL;
  do
    if [ "$SLUG" -a "$URL" ]
    then
      wp $A is-installed $SLUG || wp $A install "$URL"
    elif [ "$SLUG" ]
    then
      wp $A is-installed $SLUG || wp $A install $SLUG
    fi
  done
}

# Installs themes or plugins specified on STDIN hosted at BitBucket.
# Usage:
#   install_b plugin|theme <<< "REPO TAG"
#
# REPO is the BitBucket account/repository value.
# TAG is any tag|branch|commitish
#
# Requires $BB_KEY and $BB_SECRET environment variables.
#
function install_b {
  local A=$1
  while read REPO TAG;
  do
    if [ "$REPO" ]
    then
      # TODO add support for the 'latest' tag by omission of the tag value
      local URL="https://bitbucket.org/${REPO}/get/${TAG}.zip"
      # TODO use a mktemp file for the ZIP and clean up afterwards
      local ZIP="wp-content/${A}s/${REPO/\//.}.${TAG}.zip"
      bb $URL > $ZIP || log Tag does not exist for: $REPO @ $TAG && wp $A install $ZIP --force
    fi
  done
}

# Dirty function to call the oauth.php script
function bb {
  php /oauth.php --key "$BB_KEY" --secret "$BB_SECRET" --url "$1"
}

function install_core {
  wp core is-installed || wp core install \
      --url="$WP_URL" \
      --title="$WP_TITLE" \
      --admin_user="$WP_ADMIN_USER" \
      --admin_password="$WP_ADMIN_PASSWORD" \
      --admin_email="$WP_ADMIN_EMAIL"
}

function install_themes {
  install_a theme <<< "$WP_THEMES"
  install_b theme <<< "$BB_THEMES"
  wp theme list
}

function install_plugins {
  install_a plugin <<< "$WP_PLUGINS"
  install_b plugin <<< "$BB_PLUGINS"
  wp plugin list
}

function install {
  install_core
  install_themes
  install_plugins
  wp plugin activate --all
}

function upgrade {
  wp core update \
      && wp core update-db \
      && wp theme update --all \
      && wp plugin update --all

  # TODO fetch [a specific] tagged download from BB
}

function import {
  if ! wp plugin is-installed wordpress-importer
  then
    log "Import requires the wordpress-importer plugin, please spcifiy it in \$WP_PLUGINS"
    exit 1
  fi

  # wp option update siteurl "$WP_URL"
  # wp option update home "$WP_URL"
  echo 'Importing, this may take a *very* long time.'
  wp import $WP_IMPORT --authors=create --skip=image_resize --quiet "$@"
}

function usage {
  echo <<-EOT
    Usage: entrypoing.sh [-v] [command]
    
    Options:
    -v\t\tVerbose logging.

EOT
}

# Parse options
while getopts v OPT; do
  case $OPT in
    v) VERBOSE=true;;
    *) usage; exit 1
  esac
done
# Execute default function or command.
"${@:$OPTIND}"
