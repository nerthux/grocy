# Imagen propia de Grocy: nginx + php-fpm sobre PHP 8.5, construida desde este fork.

# Dependencias de PHP (Composer instala en packages/, ver composer.json)
# Con PHP 8.5 y no con la imagen composer, porque composer.json exige php 8.5.*
FROM php:8.5-cli-trixie AS composer
RUN apt-get update \
	&& apt-get install -y --no-install-recommends git unzip \
	&& rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_FUND=0 COMPOSER_ALLOW_SUPERUSER=1
WORKDIR /build
COPY composer.json composer.lock ./
# gd e intl se instalan en la imagen final; aquí sólo se descargan paquetes
RUN composer install --no-dev --no-interaction --no-progress --no-autoloader \
	--ignore-platform-req=ext-gd --ignore-platform-req=ext-intl
COPY helpers helpers
COPY services services
COPY controllers controllers
COPY middleware middleware
RUN composer dump-autoload --no-dev --optimize

# Dependencias del frontend (Yarn instala en public/packages, ver .yarnrc)
# Node 24: @zxing/library 0.23 lo exige
FROM node:24-trixie AS yarn
WORKDIR /build
COPY package.json yarn.lock .yarnrc ./
RUN yarn install --frozen-lockfile --non-interactive \
	&& yarn cache clean

FROM php:8.5-fpm-trixie
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		nginx \
		libfreetype6 libjpeg62-turbo libpng16-16t64 libwebp7 libicu76 \
		libfreetype-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libicu-dev \
	&& docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
	&& docker-php-ext-install -j"$(nproc)" gd intl \
	&& apt-get purge -y libfreetype-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libicu-dev \
	&& apt-get autoremove -y \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/grocy
COPY . .
COPY --from=composer /build/packages packages
COPY --from=yarn /build/public/packages public/packages
RUN chown -R www-data:www-data data

EXPOSE 80
CMD ["php-fpm"]
