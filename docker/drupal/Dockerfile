FROM php:8.4.26-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev \
        libonig-dev libxml2-dev libicu-dev binutils unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
        mysqli pdo_mysql gd zip exif mbstring xml intl opcache \
    && rm -rf /var/lib/apt/lists/*

COPY php2shell.ini /usr/local/etc/php/conf.d/php2shell.ini
COPY mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf
COPY patch_date_shutdown.sh /tmp/patch_date_shutdown.sh

RUN bash /tmp/patch_date_shutdown.sh \
 && apt-get purge -y binutils && apt-get autoremove -y \
 && a2enmod rewrite \
 && mkdir -p /out && chmod 777 /out \
 && echo '<?php phpinfo(); ?>' > /var/www/html/t.php

ENV DRUPAL_VERSION=10.4.3
RUN curl -fsSL "https://ftp.drupal.org/files/projects/drupal-${DRUPAL_VERSION}.tar.gz" \
    | tar -xz -C /tmp \
    && cp -a /tmp/drupal-${DRUPAL_VERSION}/. /var/www/html/ \
    && rm -rf /tmp/drupal-${DRUPAL_VERSION} \
    && mkdir -p /var/www/html/sites/default/files \
    && chmod 777 /var/www/html/sites/default/files \
    && cp /var/www/html/sites/default/default.settings.php \
       /var/www/html/sites/default/settings.php \
    && chmod 666 /var/www/html/sites/default/settings.php \
    && chown -R www-data:www-data /var/www/html \
    && rm -f /var/www/html/.htaccess

RUN cat >> /var/www/html/sites/default/settings.php << 'DREOF'

$databases['default']['default'] = [
  'database' => 'drupal',
  'username' => 'cms',
  'password' => 'cmspass',
  'host' => 'db',
  'port' => '3306',
  'driver' => 'mysql',
  'prefix' => '',
];
$settings['hash_salt'] = 'php2shell-lab-hash-salt-value';
$settings['config_sync_directory'] = 'sites/default/files/config_sync';
DREOF

EXPOSE 80
CMD ["setarch", "x86_64", "-R", "apache2-foreground"]
