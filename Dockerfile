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
        curl \
        zip \
        vim \
        unzip \
        supervisor \
        cron

# Copy supervisor and cron
COPY .docker/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY .docker/cron/cron /etc/cron.d/self-cron

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
    mkdir -p /var/www/app && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/log/supervisor && \
    chown -R www:www /var/www/app && \
    chown -R www:www /run && \
    chown -R www:www /var/lib/nginx && \
    chown -R www:www /var/log/nginx

COPY .docker/nginx.run /etc/service/nginx/run
COPY .docker/php.run /etc/service/php/run

RUN chmod +x /etc/service/nginx/run \
    && chmod +x /etc/service/php/run \
    && ls -al /var/www/app/

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer clear-cache

# Set prmission folder laravel
COPY --chown=www ./app /var/www/app
RUN chmod 0777 -R /var/www/app/bootstrap
RUN chmod 0777 -R /var/www/app/storage
# RUN rm -rf /root/.composer

# Clear cache Laravel
USER www
RUN cd /var/www/app && composer install
RUN cd /var/www/app && composer dump-autoload
RUN cd /var/www/app && php artisan cache:clear
RUN cd /var/www/app && php artisan config:clear
RUN cd /var/www/app && php artisan view:clear
RUN cd /var/www/app && php artisan route:clear

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/self-cron
# Apply cron job
RUN crontab /etc/cron.d/self-cron
# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Expose the port nginx is reachable on
EXPOSE 22 80
USER root
# Let boot start nginx & php-fpm & run supervisord
CMD ["sh", "/sbin/boot.sh"]
CMD ["supervisord", "--nodaemon", "--configuration", "/etc/supervisor/conf.d/supervisord.conf"]

# Healthcheck ping fpm ping
HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping
