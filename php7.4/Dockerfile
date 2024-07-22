FROM debian:11

RUN apt update -y \
    && apt install -y init locales git wget curl vim cron sudo gnupg2 tzdata php-bcmath php-curl php-fpm php-gd php-mbstring php-mysql php-redis php-sqlite3 php-xml php-yaml php-zip \
    && wget -q https://getcomposer.org/download/latest-stable/composer.phar -O /usr/local/bin/composer && chmod +x /usr/local/bin/composer
SHELL ["/bin/bash", "-c"]
RUN arch="$(uname -m)" \
    && if [ "$arch" == "i386" ] || [ "$arch" == "i686" ]; then \
            arch="x86"; \
        elif [ "$arch" == "armv6l" ] || [ "$arch" == "armv7l" ]; then \
            arch="armv7l"; \
        elif [ "$arch" == "armv8l" ] || [ "$arch" == "aarch64" ]; then \
            arch="aarch64"; \
        else \
            arch="x86-64"; \
        fi \
    && wget -q https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_"$arch".tar.gz \
    && tar xvf ioncube_loaders_lin_"$arch".tar.gz \
    && cp ioncube/ioncube_loader_lin_7.4.so /usr/lib/php/20190902/ioncube.so \
    && echo "zend_extension = /usr/lib/php/20190902/ioncube.so" > /etc/php/7.4/cli/php.ini \
    && sed -i "s/^#\?listen =.*/listen = 0.0.0.0:9000/g" /etc/php/7.4/fpm/pool.d/www.conf \
    && sed -i "s/^#\?upload_max_filesize =.*/upload_max_filesize = 1024M/g" /etc/php/7.4/cli/php.ini \
    && sed -i "s/^#\?post_max_size =.*/post_max_size = 1024M/g" /etc/php/7.4/cli/php.ini \
    && localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8 \
    && ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt clean all && rm -rf /var/lib/apt/lists/* /ioncube /ioncube_loaders_lin_"$arch".tar.gz
ENV LANG=zh_CN.UTF-8
WORKDIR /var/www
COPY --chown=www-data:www-data php7.4/docker-entrypoint /usr/bin
RUN chmod +x /usr/bin/docker-entrypoint
CMD ["docker-entrypoint"]
