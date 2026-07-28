#!/bin/sh
set -e

ENV=${ENV:-dev}
VERSION=${VERSION:-1.0.0}
BUILD_NUMBER=${BUILD_NUMBER:-0}
GIT_COMMIT=${GIT_COMMIT:-unknown}
GIT_BRANCH=${GIT_BRANCH:-unknown}
GIT_AUTHOR=${GIT_AUTHOR:-unknown}
TIMESTAMP=${TIMESTAMP:-unknown}
PIPELINE_URL=${PIPELINE_URL:-#}

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
sed -i "s|__GIT_COMMIT__|$GIT_COMMIT|g" /usr/share/nginx/html/index.html
sed -i "s|__GIT_BRANCH__|$GIT_BRANCH|g" /usr/share/nginx/html/index.html
sed -i "s|__GIT_AUTHOR__|$GIT_AUTHOR|g" /usr/share/nginx/html/index.html
sed -i "s|__TIMESTAMP__|$TIMESTAMP|g" /usr/share/nginx/html/index.html
sed -i "s|__PIPELINE_URL__|$PIPELINE_URL|g" /usr/share/nginx/html/index.html

nginx -g "daemon off;"
