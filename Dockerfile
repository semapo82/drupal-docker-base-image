# Stage 1: Build Gotpl from source
FROM golang:1.26.11-bookworm AS gotpl-builder
ARG GOTPL_VERSION=0.6.12
RUN wget -qO- "https://github.com/wodby/gotpl/archive/refs/tags/${GOTPL_VERSION}.tar.gz" | tar xz -C /tmp && \
    cd /tmp/gotpl-${GOTPL_VERSION} && \
    go build -o /usr/local/bin/gotpl

# Stage 2: Final Image
FROM php:8.4-apache-bookworm

# 1. Base Environment Variables
ENV APP_ROOT="/var/www/html" \
    CONF_DIR="/var/www/conf" \
    FILES_DIR="/mnt/files" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    PHP_INI_DIR="/usr/local/etc/php"

# 2, 3, 4, 5. Unified Installation and Cleanup in a SINGLE LAYER
RUN apt-get update && \
    apt-get install -y --only-upgrade apt libapt-pkg6.0 && \
    apt-get upgrade -y && \
    # Install Drupal Runtime dependencies
    apt-get install -y --no-install-recommends \
    libfreetype6 \
    libjpeg62-turbo \
    libpng16-16 \
    libxpm4 \
    libwebp7 \
    libavif15 \
    libmagickwand-6.q16-6 \
    libmemcached11 \
    libxslt1.1 \
    libzip4 \
    libicu72 \
    libyaml-0-2 \
    libevent-2.1-7 \
    libgmp10 \
    mariadb-client \
    postgresql-client \
    # Essential utilities for Drupal/Drush
    bash bzip2 findutils gzip jpegoptim less patch pngquant rsync tar unzip wget curl ca-certificates && \
    # Install Build-only dependencies
    apt-get install -y --no-install-recommends \
    autoconf git make gcc g++ libc-dev-bin libc6-dev linux-libc-dev \
    libbz2-dev libfreetype6-dev libjpeg-dev libmagickwand-dev libmemcached-dev \
    libpng-dev libpq-dev libssl-dev libxml2-dev libzip-dev libyaml-dev \
    libicu-dev libxslt-dev libevent-dev libgmp3-dev libwebp-dev libavif-dev && \
    # Install PHP extensions for Drupal 10/11
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-avif && \
    docker-php-ext-install -j$(nproc) \
    bcmath bz2 calendar exif gd gettext gmp intl mysqli opcache \
    pcntl pdo_mysql pdo_pgsql pgsql soap sockets xsl zip && \
    # Install PECL extensions
    pecl install apcu igbinary imagick yaml uuid uploadprogress redis memcached oauth && \
    docker-php-ext-enable apcu igbinary imagick yaml uuid uploadprogress redis memcached oauth && \
    # Install Brotli
    brotli_ext_ver="0.18.3"; \
    mkdir -p /usr/src/php/ext/brotli; \
    wget -qO- "https://github.com/kjdev/php-ext-brotli/archive/refs/tags/${brotli_ext_ver}.tar.gz" | tar xz --strip-components=1 -C /usr/src/php/ext/brotli; \
    docker-php-ext-configure brotli --with-libbrotli; \
    docker-php-ext-install brotli && \
    # --- SAFE CLEANUP PHASE ---
    # We remove ONLY the source of vulnerabilities, NOT the system dependencies
    # This ensures a2enmod and Apache remain intact
    apt-get purge -y \
    git git-man python3 python3.11 python3.11-minimal python3-minimal \
    libpython3.11-minimal libpython3.11-stdlib \
    binutils binutils-common libbinutils \
    autoconf make gcc g++ \
    *-dev \
    libtidy5deb1 && \
    # Manual cleanup of build artifacts
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/src/php/ext/brotli /root/.pearrc

# 6. Install CLI tools
COPY --from=composer:2.9.8 /usr/bin/composer /usr/local/bin/composer
COPY --from=gotpl-builder /usr/local/bin/gotpl /usr/local/bin/gotpl

# Drush symlink (Requires vendor/bin/drush to exist after composer install in child images)
RUN ln -sf /var/www/html/vendor/bin/drush /usr/local/bin/drush

# 7. Apache Configuration
# These commands will now work because Apache was not purged
RUN a2enmod rewrite headers proxy proxy_http ssl expires remoteip && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# SECURITY: Apply ImageMagick security policy
COPY imagemagick-policy.xml /etc/ImageMagick-6/policy.xml

# Templates and entrypoint
COPY templates/ /etc/gotpl/
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# 8. Final permissions
RUN chown -R www-data:www-data /var/www/html

WORKDIR $APP_ROOT
EXPOSE 8080
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["apache2-foreground"]