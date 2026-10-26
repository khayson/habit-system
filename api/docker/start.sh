#!/bin/sh
# A54: Render's free tier has no pre-deploy step, so the one instance migrates as it starts.
set -eu
cd /var/www/html

php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan migrate --force --no-interaction

# Render mounts an empty /tmp when the container runs, so nginx's folders are made here.
mkdir -p /tmp/nginx
sed "s/__PORT__/${PORT:-10000}/" /etc/nginx/habit.conf.template > /tmp/nginx/nginx.conf
php-fpm --nodaemonize &
exec nginx -e /dev/stderr -c /tmp/nginx/nginx.conf -g 'daemon off;'
