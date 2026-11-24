# Copilot Instructions for scib-docker-base-image

This is a Docker base image for PHP 8.3 with Apache 2.4 and Drupal-optimized extensions. The image is designed to serve as a foundation for Drupal 10/11 projects with production-ready PHP extensions, security hardening, and dynamic configuration templates.

## Quick Build & Verify

```bash
# Build the image
docker build -t scib-docker-base:8.3-latest .

# Verify it can start
docker run --rm scib-docker-base:8.3-latest apache2-foreground &
sleep 2 && curl http://localhost:8080
```

## Architecture Overview

### Multi-Stage Build
- **Stage 1 (gotpl-builder)**: Builds the Gotpl CLI tool from source (v0.6.1) using Go 1.26.1. This is needed because pre-built Gotpl binaries aren't available in standard repos and Gotpl is critical for template processing.
- **Stage 2 (final)**: PHP 8.3 Apache image based on Debian Bookworm with all dependencies.

### Key Components

#### 1. **Entrypoint System** (`docker-entrypoint.sh`)
- Processes templates at container startup using Gotpl (template variables → config files)
- Disables PHP extensions via `PHP_EXTENSIONS_DISABLE` environment variable
- Supports backwards compatibility for `APACHE_SERVER_ROOT` → `APACHE_DOCUMENT_ROOT`
- Forwards to Apache or executes custom commands

#### 2. **Templates** (`templates/` directory)
Generated at runtime from Gotpl templates:
- `vhost.conf.tmpl`: Virtual host configuration with document root and proxy settings
- `docker-php-8.3.ini.tmpl`: PHP 8.3-specific php.ini settings (memory, post size, opcache tuning)
- `docker-php-ext-*.ini.tmpl`: Individual extension configs (APCu, igbinary, opcache, brotli)
- `httpd.conf.tmpl`: Main Apache config
- `mpm.conf.tmpl`: Apache MPM (multi-process module) tuning
- `mime.types.tmpl`: MIME type mappings

#### 3. **PHP Extensions** (Production-Ready)
Installed as core:
- **Core**: bcmath, bz2, calendar, exif, gd (with freetype, jpeg, webp), gettext, gmp, intl, mysqli, opcache, pcntl, pdo_mysql, pdo_pgsql, pgsql, soap, sockets, xsl, zip
- **PECL**: apcu, igbinary, imagick, yaml, uuid, uploadprogress, redis, memcached, oauth, brotli

#### 4. **Security Hardening**
- ImageMagick policy file applied (`imagemagick-policy.xml`) to prevent CVE exploitation
- Build-time cleanup removes: Python, development tools, git, binutils (reduces CVE surface)
- Single RUN layer for installation + cleanup minimizes layer bloat and CVE exposure
- Apache listens on port 8080 (non-standard, safer than 80)

#### 5. **Helper Scripts** (`bin/` directory)
- `init_container`: Creates and chowns application directories (FILES_DIR, sessions, xdebug) for www-data
- `actions.mk`: Makefile with targets for files linking and live checks
- `files_chmod`, `files_chown`: Permission helpers for shared volumes

## Configuration via Environment Variables

### Apache
```bash
APACHE_DOCUMENT_ROOT=/var/www/html     # Document root (required)
APACHE_CONFDIR=/etc/apache2             # Apache config dir
APACHE_RUN_USER=www-data                # Apache process user
APACHE_RUN_GROUP=www-data               # Apache process group
APACHE_SERVER_ROOT=...                  # Deprecated, use APACHE_DOCUMENT_ROOT
```

### PHP
```bash
PHP_MEMORY_LIMIT=256M                   # Available in php.ini template
PHP_MAX_POST_SIZE=100M                  # Available in php.ini template
PHP_EXTENSIONS_DISABLE=redis,memcached  # Comma-separated list of extensions to disable
```

### Directories
```bash
APP_ROOT=/var/www/html                  # Application root
CONF_DIR=/var/www/conf                  # Configuration directory
FILES_DIR=/mnt/files                    # Persistent files (logs, uploads, etc.)
```

## Troubleshooting Template Processing

If templates fail to process:
1. Check `PHP_EXTENSIONS_DISABLE` variable format (comma-separated, no spaces)
2. Verify environment variables are exported (not just set in shell)
3. Review entrypoint output for permission errors on mounted volumes
4. If rebuild-time template processing needed, verify all variables are set before image build

## Working with Drupal

This image is optimized for Drupal 10/11. Child images should:
1. Ensure `composer install` runs to populate `/var/www/html/vendor/bin/drush`
2. Set `APACHE_DOCUMENT_ROOT` to the web root (typically `/var/www/html/web` for Composer-managed Drupal)
3. Include Drupal in the image or mount as volume
4. Use Xdebug directory if debugging needed: `FILES_DIR/xdebug`

## Key File Locations in Image

```
/etc/gotpl/              → Template sources
/etc/apache2/            → Apache configuration
/usr/local/etc/php/      → PHP configuration
/var/www/html/           → Application root (APP_ROOT)
/mnt/files/              → Persistent storage (logs, sessions, etc.)
```

## Build Optimization Notes

- All package installation happens in a single RUN layer with unified cleanup to minimize image size and CVE footprint
- Development tools are purged after compilation; only runtime dependencies remain
- Brotli extension is built from source since it's not in standard PHP packages
- Composer and Gotpl are copied from official images (multi-stage) to avoid build time overhead
