FROM php:8.5-fpm-alpine

ADD --chmod=0755 https://raw.githubusercontent.com/elesssss/dnmp/main/Docker/php8.5/install-php-extensions /usr/local/bin/
ADD --chmod=0755 https://getcomposer.org/download/latest-stable/composer.phar /usr/local/bin/composer

RUN install-php-extensions bcmath gd ioncube_loader mysqli opcache pdo_mysql redis swoole yaml zip \
    && rm -rf /var/cache/apk/*

RUN echo "upload_max_filesize=1024M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size=1024M" > /usr/local/etc/php/conf.d/post.ini \
    && echo "memory_limit=512M" > /usr/local/etc/php/conf.d/memory.ini \
    && echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini \
    && echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini \
    && echo "max_input_vars=10000" > /usr/local/etc/php/conf.d/max_input_vars.ini
