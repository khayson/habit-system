# syntax=docker/dockerfile:1.7
# A54: the API for Render's free web service (Docker). PHP 8.4 with php-fpm and nginx in one
# container, running as a non-root user and listening on Render's PORT. php-fpm in classic mode:
# one request per process lifetime, as static state and defer() assume.

FROM php:8.4-fpm-alpine AS base
COPY --from=mlocati/php-extension-installer:2.7 /usr/bin/install-php-extensions /usr/local/bin/
# pdo_pgsql (Neon), zip (exports), gd with JPEG and WebP (avatars, A20), opcache, pcntl (worker
# time limits in the tick).
RUN install-php-extensions pdo_pgsql zip gd opcache pcntl \
    && apk add --no-cache nginx \
    && rm -f /usr/local/bin/install-php-extensions

FROM base AS vendor
COPY --from=composer:2.8 /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --prefer-dist --no-interaction --no-progress --no-scripts --no-autoloader
COPY . .
RUN composer dump-autoload --no-dev --optimize --classmap-authoritative \
    && rm -rf storage/logs/* storage/framework/cache/data/* storage/framework/views/*

FROM base
ENV APP_ENV=production \
    APP_DEBUG=false \
    LOG_CHANNEL=stderr \
    LOG_LEVEL=warning \
    PORT=10000 \
    PGCONNECT_TIMEOUT=5
RUN addgroup -S app && adduser -S -G app -h /var/www app \
    && rm -f /usr/local/etc/php-fpm.d/*.conf
COPY docker/php.ini /usr/local/etc/php/conf.d/zz-habit.ini
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/zz-habit.conf
COPY docker/nginx.conf /etc/nginx/habit.conf.template
COPY docker/start.sh /usr/local/bin/habit-start
COPY --from=vendor --chown=app:app /app /var/www/html
RUN chmod 0755 /usr/local/bin/habit-start \
    && mkdir -p /tmp/nginx \
    && chown -R app:app /tmp/nginx /var/www/html/storage /var/www/html/bootstrap/cache
WORKDIR /var/www/html
USER app
EXPOSE 10000
CMD ["habit-start"]
