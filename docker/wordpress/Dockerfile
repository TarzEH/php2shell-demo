FROM php:8.4.26-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
        libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev \
        libonig-dev libxml2-dev libicu-dev binutils \
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

ENV WORDPRESS_VERSION=6.7.1
RUN curl -fsSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" \
    | tar -xz -C /tmp \
    && cp -a /tmp/wordpress/. /var/www/html/ \
    && rm -rf /tmp/wordpress \
    && chown -R www-data:www-data /var/www/html

RUN cat > /var/www/html/wp-config.php << 'WPEOF'
<?php
define('DB_NAME',     getenv('WORDPRESS_DB_NAME') ?: 'wordpress');
define('DB_USER',     getenv('WORDPRESS_DB_USER') ?: 'cms');
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'cmspass');
define('DB_HOST',     getenv('WORDPRESS_DB_HOST') ?: 'db');
define('DB_CHARSET',  'utf8mb4');
define('DB_COLLATE',  '');
define('AUTH_KEY',         'php2shell-lab-key-1');
define('SECURE_AUTH_KEY',  'php2shell-lab-key-2');
define('LOGGED_IN_KEY',    'php2shell-lab-key-3');
define('NONCE_KEY',        'php2shell-lab-key-4');
define('AUTH_SALT',        'php2shell-lab-salt-1');
define('SECURE_AUTH_SALT', 'php2shell-lab-salt-2');
define('LOGGED_IN_SALT',   'php2shell-lab-salt-3');
define('NONCE_SALT',       'php2shell-lab-salt-4');
$table_prefix = 'wp_';
define('WP_DEBUG', false);
if (!defined('ABSPATH')) define('ABSPATH', __DIR__ . '/');
require_once ABSPATH . 'wp-settings.php';
WPEOF

EXPOSE 80
CMD ["setarch", "x86_64", "-R", "apache2-foreground"]
