
ARG EXT="pdo pdo_sqlite pdo_pgsql pdo_odbc pdo_mysql pdo_dblib"
ARG PECL_EXT="redis protobuf mongodb memcache"
ARG USER_UID=1000
ARG USER_GID=1000

FROM devoptimus/php-composer as admin_composer

ARG EXT
ARG PECL_EXT
ARG USER_UID
ARG USER_GID
ENV UID=${USER_GID}
ENV GID=${USER_GID}


RUN addgroup -g ${UID} app \
    && adduser -h /home/app -G app -u ${GID} -D app \
    && install-php-ext ${EXT} \
    && install-php-pecl-ext ${PECL_EXT} \
    && mkdir -p /home/app/public_html /home/app/public_html/bin \
    && chown app:app /home/app -R

WORKDIR /home/app/public_html
USER app
COPY --chown=app admin/composer.json ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist
COPY --chown=app admin .
RUN composer install --no-dev --prefer-dist

#
# Fontend NODEJS/NPM
#
FROM node:alpine as admin_frontend
COPY --from=admin_composer /home/app/public_html /home/app/public_html
WORKDIR /home/app/public_html
RUN npm install && npm run build && rm -r node_modules

#
# CLI PHP
#
FROM devoptimus/php-cli as admin_cli

ARG EXT
ARG PECL_EXT
ARG USER_UID
ARG USER_GID
ENV UID=${USER_GID}
ENV GID=${USER_GID}


COPY --from=admin_composer /home/app/public_html /home/app/public_html
COPY --from=admin_frontend /home/app/public_html/public /home/app/public_html/public

RUN addgroup -g ${UID} app \
    && adduser -h /home/app -G app -u ${GID} -D app \
    && apk add --no-cache busybox-suid \
    && install-php-ext ${EXT} \
    && install-php-pecl-ext ${PECL_EXT} \
    && chown app:app /home/app -R

USER app
WORKDIR /home/app/public_html


#
# FPM PHP
#
FROM devoptimus/php-fpm as admin_fpm
ARG EXT
ARG PECL_EXT
ARG USER_UID
ARG USER_GID
ENV UID=${USER_GID}
ENV GID=${USER_GID}

COPY --from=admin_composer /home/app/public_html /home/app/public_html
COPY --from=admin_frontend /home/app/public_html/public /home/app/public_html/public
COPY docker/www.ini /etc/php/fpm/pool.d/

RUN addgroup -g ${UID} app \
    && adduser -h /home/app -G app -u ${GID} -D app \
    && chown app:app /home/app -R \
    && install-php-ext ${EXT} fpm \
    && install-php-pecl-ext ${PECL_EXT}

WORKDIR /home/app/public_html

USER app
RUN php artisan event:cache \
    && php artisan route:cache \
    && php artisan view:cache

USER daemon

#
# NGINX
#
FROM devoptimus/nginx as admin_nginx
COPY admin/resources/docker/default.template /etc/nginx/template.d/
COPY --from=fpm /home/app/public_html/public /home/app/public_html/public
WORKDIR /home/app/public_html/public

#
# CRONTAB
#
FROM admin_cli as admin_cron
USER app
RUN echo "* * * * * cd /home/app/public_html && php artisan schedule:run" >> laravel.cron
RUN crontab laravel.cron
CMD ["crond", "-l", "2", "-f"]

FROM admin_cli