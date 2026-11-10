FROM php:8.4.26-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev \
        libonig-dev libxml2-dev libicu-dev binutils unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mysqli pdo_mysql gd zip mbstring xml opcache intl \
    && rm -rf /var/lib/apt/lists/*

COPY php2shell.ini /usr/local/etc/php/conf.d/php2shell.ini
COPY mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf
COPY patch_date_shutdown.sh /tmp/patch_date_shutdown.sh

RUN bash /tmp/patch_date_shutdown.sh \
 && apt-get purge -y binutils && apt-get autoremove -y \
 && a2enmod rewrite \
 && mkdir -p /out && chmod 777 /out \
 && echo '<?php phpinfo(); ?>' > /var/www/html/t.php

ENV JOOMLA_VERSION=5.2.4
RUN mkdir -p /tmp/joomla \
    && curl -fsSL "https://github.com/joomla/joomla-cms/releases/download/${JOOMLA_VERSION}/Joomla_${JOOMLA_VERSION}-Stable-Full_Package.tar.gz" \
       -o /tmp/joomla.tar.gz \
    && tar -xzf /tmp/joomla.tar.gz -C /tmp/joomla \
    && cp -a /tmp/joomla/. /var/www/html/ \
    && rm -rf /tmp/joomla /tmp/joomla.tar.gz \
    && chown -R www-data:www-data /var/www/html

RUN cat > /var/www/html/configuration.php << 'JMEOF'
<?php
class JConfig {
    public $dbtype = 'mysqli';
    public $host = 'db';
    public $user = 'cms';
    public $password = 'cmspass';
    public $db = 'joomla';
    public $dbprefix = 'jml_';
    public $dbencryption = 0;
    public $secret = 'php2shell-lab-joomla-secret';
    public $sitename = 'PHP2Shell Lab - Joomla';
    public $log_path = '/var/www/html/administrator/logs';
    public $tmp_path = '/var/www/html/tmp';
    public $offset = 'UTC';
    public $error_reporting = 'default';
    public $sef = true;
    public $sef_rewrite = false;
    public $session_handler = 'database';
    public $lifetime = 15;
}
JMEOF

EXPOSE 80
CMD ["setarch", "x86_64", "-R", "apache2-foreground"]
