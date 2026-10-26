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
# Wait (up to about 10 s) until PHP-FPM listens, so nginx's first requests never meet a closed port.
tries=0
until php -r 'exit(@fsockopen("127.0.0.1", 9000) ? 0 : 1);' || [ "$tries" -ge 50 ]; do
    tries=$((tries + 1))
    sleep 0.2
done
exec nginx -e /dev/stderr -c /tmp/nginx/nginx.conf -g 'daemon off;'
