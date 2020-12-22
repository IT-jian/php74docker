FROM php:7.4.12-fpm-alpine3.12


RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# Environments
ENV TIMEZONE            Asia/Shanghai
ENV PHP_MEMORY_LIMIT    512M
ENV MAX_UPLOAD          50M
ENV PHP_MAX_FILE_UPLOAD 200
ENV PHP_MAX_POST        100M
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV CODE_PATH /usr/share/nginx/html
ENV PHP_ENV_FILE .env_production

#安装基本工具
RUN apk add --update nginx \
openssh \
supervisor \
git \
curl \
curl-dev \
make \
zlib-dev \
build-base \
zsh \
vim \
vimdiff \
wget \
sudo

#2.ADD-PHP-FPM
LABEL vendor="wulaphp Dev Team" \
    version="7.4.12-ng-alphine" \
    description="Official wulaphp docker image with specified extensions"

# COPY docker-ng-entrypoint.sh /usr/local/bin/docker-ng-entrypoint

RUN apk update &&\
    apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS&&\
    apk add --no-cache libpng-dev zlib-dev libzip-dev libmemcached-dev freetype-dev;\
    pecl channel-update pecl.php.net;\
    pecl install redis-5.3.1;\
    pecl install memcached-3.1.5;\
    pecl install yac-2.2.1;\
    docker-php-ext-enable redis memcached yac;\
    echo "yac.enable_cli = On" >> /usr/local/etc/php/conf.d/docker-php-ext-yac.ini;\
    sed -i 's/apk add --no-cache/#apk add --no-cache/' /usr/local/bin/docker-php-ext-install;\
    docker-php-ext-configure gd --with-freetype;\
    docker-php-ext-install -j$(nproc) gd pcntl \
    sockets bcmath pdo_mysql opcache mbstring xml zip;\
    cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini;\
    apk del --no-network .phpize-deps;\
    apk add --no-cache nginx;\
    mv /etc/nginx /usr/local/etc/nginx;ln -s /usr/local/etc/nginx /etc/nginx;\
    pecl clear-cache;\
    rm -rf /tmp/pear/;\
    rm -rf /usr/src/php* /var/lib/apk/* /var/cache/apk/* /usr/local/etc/php-fpm.d/*.conf;



RUN mkdir -p /usr/local/var/log/php7/
RUN mkdir -p /usr/local/var/run/
COPY docker/php/php-fpm.conf /etc/php7/
COPY docker/php/php-fpm.conf /usr/local/etc/
COPY docker/php/www.conf /etc/php7/php-fpm.d/



# Set environments
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /usr/local/etc/php/php.ini-production && \
       sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /usr/local/etc/php/php.ini-production && \
       sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /usr/local/etc/php/php.ini-production && \
       sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /usr/local/etc/php/php.ini-production && \
       sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /usr/local/etc/php/php.ini-production && \
       sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /usr/local/etc/php/php.ini-production

#3.Install-Composer
RUN curl -sS https://getcomposer.org/installer | \
    php -- --install-dir=/usr/bin/ --filename=composer


#4.ADD-NGINX
RUN apk add nginx
COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/
COPY docker/nginx/nginx.conf /etc/nginx/
COPY docker/nginx/cert/ /etc/nginx/cert/

RUN mkdir -p /usr/share/nginx/html/public/
COPY docker/php/index.php /usr/share/nginx/html/public/


VOLUME ["/usr/share/nginx/html", "/usr/local/var/log/php7", "/var/run/"]
WORKDIR /usr/share/nginx/html


#5.ADD-SUPERVISOR
RUN apk add supervisor \
 && rm -rf /var/cache/apk/*

# Define mountable directories.
VOLUME ["/etc/supervisor/conf.d", "/var/log/supervisor/"]
COPY docker/supervisor/conf.d/ /etc/supervisor/conf.d/

#6.ADD-CRONTABS
COPY docker/crontabs/default /var/spool/cron/crontabs/
RUN cat /var/spool/cron/crontabs/default >> /var/spool/cron/crontabs/root
RUN mkdir -p /var/log/cron \
 && touch /var/log/cron/cron.log

VOLUME /var/log/cron


#7.添加启动脚本
# Define working directory.
WORKDIR /usr/share/nginx/html
COPY docker/entrypoint.sh /usr/share/nginx/
RUN chmod +x /usr/share/nginx/entrypoint.sh

ENTRYPOINT ["/usr/share/nginx/entrypoint.sh"]

EXPOSE 80
