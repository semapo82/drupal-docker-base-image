# scib-docker-base-image

Imagen Docker base para proyectos **Drupal 11**, construida sobre PHP 8.4 + Apache 2.4 en Debian Bookworm. Diseñada para usarse como `FROM` en imágenes de proyecto, aportando todas las extensiones PHP necesarias, configuración dinámica por variables de entorno y hardening de seguridad listo para producción.

---

## Índice

- [Construcción](#construcción)
- [Arquitectura](#arquitectura)
- [Extensiones PHP incluidas](#extensiones-php-incluidas)
- [Variables de entorno](#variables-de-entorno)
- [Sistema de plantillas (Gotpl)](#sistema-de-plantillas-gotpl)
- [Scripts de ayuda](#scripts-de-ayuda)
- [Usar como imagen base](#usar-como-imagen-base)
- [Seguridad](#seguridad)
- [Herramientas de IA (Skills)](#herramientas-de-ia-skills)

---

## Construcción

```bash
docker build -t scib-docker-base:8.4-latest .
```

Verificar que arranca:

```bash
docker run --rm -p 8080:8080 scib-docker-base:8.4-latest
curl http://localhost:8080
```

---

## Arquitectura

La imagen se construye en **dos etapas**:

| Etapa | Base | Propósito |
|---|---|---|
| `gotpl-builder` | `golang:1.26.2-bookworm` | Compila [Gotpl v0.6.1](https://github.com/wodby/gotpl) desde fuente |
| `final` | `php:8.4-apache-bookworm` | Imagen definitiva con todas las dependencias |

Todo el proceso de instalación (dependencias, extensiones PHP, PECL, Brotli) ocurre en **una sola capa `RUN`** seguida de una fase de limpieza. Esto minimiza el tamaño de la imagen y reduce la superficie de CVEs eliminando herramientas de compilación que no son necesarias en tiempo de ejecución.

---

## Extensiones PHP incluidas

### Extensiones core

| Extensión | Descripción |
|---|---|
| `bcmath` | Aritmética de precisión arbitraria |
| `bz2` | Compresión Bzip2 |
| `calendar` | Conversión de calendarios |
| `exif` | Metadatos de imágenes |
| `gd` | Procesado de imágenes (freetype, jpeg, webp) |
| `gettext` | Internacionalización |
| `gmp` | Aritmética de precisión múltiple |
| `intl` | Internacionalización (ICU) |
| `mysqli` / `pdo_mysql` | MySQL / MariaDB |
| `opcache` | Caché de bytecode (con JIT) |
| `pcntl` | Control de procesos |
| `pdo_pgsql` / `pgsql` | PostgreSQL |
| `soap` | Servicios web SOAP |
| `sockets` | Sockets de bajo nivel |
| `xsl` | Transformaciones XSLT |
| `zip` | Archivos ZIP |

### Extensiones PECL

| Extensión | Descripción |
|---|---|
| `apcu` | Caché de usuario en memoria |
| `igbinary` | Serializador binario (mejora rendimiento de Redis/Memcached) |
| `imagick` | ImageMagick |
| `yaml` | Soporte YAML |
| `uuid` | Generación de UUIDs |
| `uploadprogress` | Progreso de subida de ficheros |
| `redis` | Cliente Redis |
| `memcached` | Cliente Memcached |
| `oauth` | Autenticación OAuth |
| `brotli` | Compresión Brotli (compilado desde fuente) |

---

## Variables de entorno

### Apache

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `APACHE_DOCUMENT_ROOT` | `/var/www/html` | Raíz de documentos |
| `APACHE_PORT` | `8080` | Puerto de escucha |
| `APACHE_SERVER_NAME` | `default` | ServerName |
| `APACHE_DIRECTORY_INDEX` | `index.php` | DirectoryIndex |
| `APACHE_ALLOW_OVERRIDE_ENABLED` | `All` | AllowOverride |
| `APACHE_INDEXES_ENABLED` | *(vacío)* | Activar listado de directorios |
| `APACHE_LIMITED_ACCESS` | *(vacío)* | Restringir acceso global |
| `APACHE_HTTP2` | *(vacío)* | Activar HTTP/2 |
| `APACHE_SERVER_ROOT` | — | **Obsoleto** — usar `APACHE_DOCUMENT_ROOT` |

### PHP

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `PHP_MEMORY_LIMIT` | `1024M` (CLI) | Límite de memoria |
| `PHP_DISPLAY_ERRORS` | `Off` | Mostrar errores |
| `PHP_ERROR_REPORTING` | `E_ALL` | Nivel de reporte |
| `PHP_DATE_TIMEZONE` | `UTC` | Zona horaria |
| `PHP_REALPATH_CACHE_SIZE` | `16M` | Caché de rutas reales |
| `PHP_OPCACHE_ENABLE` | `1` | Activar OPcache |
| `PHP_OPCACHE_JIT` | `tracing` | Modo JIT |
| `PHP_OPCACHE_JIT_BUFFER_SIZE` | `64M` | Buffer JIT |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | `256` | Memoria OPcache (MB) |
| `PHP_OPCACHE_PRELOAD` | *(vacío)* | Fichero de preload |
| `PHP_EXTENSIONS_DISABLE` | *(vacío)* | Extensiones a desactivar, separadas por coma (ej: `redis,memcached`) |

### Sesiones PHP

| Variable | Valor por defecto |
|---|---|
| `PHP_SESSION_SAVE_HANDLER` | `files` |
| `PHP_SESSION_SAVE_PATH` | `/mnt/files/sessions` |
| `PHP_SESSION_COOKIE_SECURE` | `1` |
| `PHP_SESSION_COOKIE_HTTPONLY` | `1` |
| `PHP_SESSION_COOKIE_SAMESITE` | `Strict` |

### Directorios

| Variable | Valor por defecto | Descripción |
|---|---|---|
| `APP_ROOT` | `/var/www/html` | Raíz de la aplicación |
| `CONF_DIR` | `/var/www/conf` | Directorio de configuración |
| `FILES_DIR` | `/mnt/files` | Almacenamiento persistente (logs, uploads, sesiones, xdebug) |

---

## Sistema de plantillas (Gotpl)

Al arrancar el contenedor, el entrypoint procesa automáticamente las plantillas de `/etc/gotpl/` usando [Gotpl](https://github.com/wodby/gotpl), que sustituye variables de entorno en los ficheros de configuración.

| Plantilla | Destino generado |
|---|---|
| `vhost.conf.tmpl` | `/etc/apache2/conf-available/vhost.conf` |
| `mpm.conf.tmpl` | `/etc/apache2/conf-available/http-mpm.conf` |
| `mime.types.tmpl` | `/etc/apache2/conf-available/mime.types` |
| `docker-php-8.4.ini.tmpl` | `/usr/local/etc/php/conf.d/docker-php.ini` |
| `docker-php-ext-apcu.ini.tmpl` | `/usr/local/etc/php/conf.d/docker-php-ext-apcu.ini` |
| `docker-php-ext-opcache.ini.tmpl` | `/usr/local/etc/php/conf.d/docker-php-ext-opcache.ini` |
| `docker-php-ext-igbinary.ini.tmpl` | `/usr/local/etc/php/conf.d/docker-php-ext-igbinary.ini` |
| `docker-php-ext-brotli.ini.tmpl` | `/usr/local/etc/php/conf.d/docker-php-ext-brotli.ini` |

---

## Scripts de ayuda

Disponibles en `/usr/local/bin/` dentro del contenedor (copiados desde `bin/`):

| Script | Descripción |
|---|---|
| `init_container` | Crea y asigna permisos a `FILES_DIR`, `sessions` y `xdebug` para `www-data` |
| `files_chown` | Cambia el propietario de ficheros en volúmenes compartidos |
| `files_chmod` | Ajusta permisos en volúmenes compartidos |
| `actions.mk` | Makefile con targets para verificación de salud (`check-live`) y enlace de ficheros (`files-link`) |

---

## Usar como imagen base

```dockerfile
FROM scib-docker-base:8.4-latest

# Copiar el código Drupal
COPY . /var/www/html

# Instalar dependencias de Composer
RUN composer install --no-dev --optimize-autoloader

# El DocumentRoot de Drupal está en /web
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web
```

> **Nota:** El symlink `/usr/local/bin/drush` apunta a `/var/www/html/vendor/bin/drush`.
> Asegúrate de ejecutar `composer install` en la imagen hija para que Drush esté disponible.

---

## Seguridad

- **Puerto 8080** — Apache no escucha en el puerto 80 por defecto.
- **ImageMagick policy** — Se aplica `imagemagick-policy.xml` en tiempo de build para mitigar CVEs conocidos de ImageMagick.
- **Limpieza de herramientas de compilación** — `git`, `gcc`, `binutils`, herramientas Python y todos los paquetes `*-dev` se eliminan tras la compilación de extensiones.
- **Headers de seguridad** — Los módulos `headers`, `expires` y `remoteip` están habilitados en Apache.

### Escaneo de vulnerabilidades

El repositorio incluye un resultado de escaneo de referencia en `trivy_scan_result_8.3-1.0.2.txt`.

Para escanear una nueva versión de la imagen:

```bash
trivy image --scanners vuln --format json \
  --output trivy_scan_result_<version>.json \
  scib-docker-base:<version>
```

---

## Herramientas de IA (Skills)

Este repositorio incluye un skill de Copilot CLI para detectar y corregir vulnerabilidades fixables en la imagen Docker.

### Instalación (una vez por máquina)

```bash
cp -r .agents/skills/trivy-vulnerability-fixer ~/.agents/skills/
```

### Uso

Una vez instalado, en cualquier sesión de Copilot CLI dentro del proyecto puedes usar frases como:

- *"Escanea la imagen scib-docker-base:8.4-latest con trivy y dime qué vulnerabilidades fixables hay"*
- *"Tengo 457 vulns en mi imagen Docker, ayúdame a reducirlas antes del próximo release"*
- *"Ya tengo el resultado de trivy en trivy_scan_result_8.3-1.0.2.txt, qué hago?"*

El skill ejecuta el flujo completo: escanea con `--format json`, filtra solo las vulnerabilidades con fix disponible, propone cambios concretos en el Dockerfile y **espera tu aprobación** antes de modificar cualquier fichero.
