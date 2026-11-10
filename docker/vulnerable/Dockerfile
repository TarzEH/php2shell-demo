FROM php:8.4.26-apache

COPY php2shell.ini /usr/local/etc/php/conf.d/php2shell.ini
COPY mpm_prefork.conf /etc/apache2/mods-enabled/mpm_prefork.conf
COPY patch_date_shutdown.sh /tmp/patch_date_shutdown.sh

RUN apt-get update && apt-get install -y --no-install-recommends binutils \
 && bash /tmp/patch_date_shutdown.sh \
 && apt-get purge -y binutils && apt-get autoremove -y && rm -rf /var/lib/apt/lists/* \
 && echo '<?php phpinfo(); ?>' > /var/www/html/index.php \
 && mkdir -p /out && chmod 777 /out

EXPOSE 80

CMD ["setarch", "x86_64", "-R", "apache2-foreground"]
