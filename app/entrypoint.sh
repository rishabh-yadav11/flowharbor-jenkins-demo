#!/bin/sh
set -e

ENV=${ENV:-dev}
VERSION=${VERSION:-1.0.0}
BUILD_NUMBER=${BUILD_NUMBER:-0}

case "$ENV" in
  dev)     LABEL="Dev" ;;
  staging) LABEL="Staging" ;;
  prod)    LABEL="Production" ;;
  *)       LABEL="Unknown" ;;
esac

sed -i "s|__ENV__|$ENV|g" /usr/share/nginx/html/index.html
sed -i "s|__ENV_LABEL__|$LABEL|g" /usr/share/nginx/html/index.html
sed -i "s|__VERSION__|$VERSION|g" /usr/share/nginx/html/index.html
sed -i "s|__BUILD_NUMBER__|$BUILD_NUMBER|g" /usr/share/nginx/html/index.html

nginx -g "daemon off;"
