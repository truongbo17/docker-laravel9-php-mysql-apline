FROM alpine:3.17

# Install packages
RUN apk --no-cache add \
        php81 \
        php81-fpm \
        php81-opcache \
        php81-pecl-apcu \
        php81-mysqli \
        php81-pgsql \
        php81-json \
        php81-openssl \
        php81-curl \
        php81-zlib \
        php81-soap \
        php81-xml \
        php81-fileinfo \
        php81-xmlwriter \
        php81-phar \
        php81-intl \
        php81-dom \
        php81-xmlreader \
        php81-ctype \
        php81-session \
        php81-iconv \
        php81-tokenizer \
        php81-zip \
        php81-simplexml \
        php81-mbstring \
        php81-pdo \
        php81-gd \
        nginx \
        runit \
        curl

# Configure nginx
COPY .docker/nginx.conf /etc/nginx/nginx.conf
ADD .docker/sites/*.conf /etc/nginx/conf.d/
# Remove default server definition
RUN echo '' > /etc/nginx/conf.d/default.conf
RUN rm /etc/nginx/conf.d/default.conf

# Configure PHP-FPM
COPY .docker/fpm-pool.conf /etc/php8.1/php-fpm.d/www.conf
COPY .docker/php.ini /etc/php8.1/conf.d/custom.ini

# Configure runit boot script
COPY .docker/boot.sh /sbin/boot.sh

RUN adduser -D -u 1000 -g 1000 -s /bin/sh www && \
    mkdir -p /var/www/api && \
    mkdir -p /var/cache/nginx && \
    chown -R www:www /var/www/api && \
    chown -R www:www /run && \
    chown -R www:www /var/lib/nginx && \
    chown -R www:www /var/log/nginx

COPY .docker/nginx.run /etc/service/nginx/run
COPY .docker/php.run /etc/service/php/run

RUN chmod +x /etc/service/nginx/run \
    && chmod +x /etc/service/php/run \
    && ls -al /var/www/api/


# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer clear-cache

# Set prmission folder laravel
COPY --chown=www ./app /var/www/api
RUN chmod 0777 -R /var/www/api/bootstrap
RUN chmod 0777 -R /var/www/api/storage
# RUN rm -rf /root/.composer

USER www
RUN cd /var/www/api && composer install
RUN cd /var/www/api && composer dump-autoload
RUN cd /var/www/api && php artisan cache:clear
RUN cd /var/www/api && php artisan config:clear
RUN cd /var/www/api && php artisan view:clear
RUN cd /var/www/api && php artisan route:clear

# Expose the port nginx is reachable on
EXPOSE 80
USER root
# Let boot start nginx & php-fpm
CMD ["sh", "/sbin/boot.sh"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping
