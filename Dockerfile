FROM php:8.3-apache

RUN docker-php-ext-install pdo_mysql

WORKDIR /var/www/html

COPY . /var/www/html

RUN { \
    echo "display_errors=Off"; \
    echo "html_errors=Off"; \
    echo "log_errors=On"; \
} > /usr/local/etc/php/conf.d/invernadero.ini
