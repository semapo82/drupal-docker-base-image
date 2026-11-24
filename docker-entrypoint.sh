#!/usr/bin/env bash

set -eo pipefail

[[ -n "${DEBUG}" ]] && set -x

# Función para procesar plantillas solo si el usuario tiene permisos de escritura
_gotpl() {
  if [[ -f "/etc/gotpl/$1" ]]; then
    # Intentamos escribir. Si falla por permisos (porque ya se hizo en el build como root),
    # simplemente avisamos y continuamos para no romper el arranque.
    if gotpl "/etc/gotpl/$1" > "$2" 2>/dev/null; then
      echo "✅ Configuración generada: $2"
    else
      echo "ℹ️  Omitiendo $1: El archivo ya existe o no hay permisos de escritura (Build-time config)."
    fi
  fi
}

_backwards_compatibility() {
  if [[ -n "${APACHE_SERVER_ROOT}" && -z "${APACHE_DOCUMENT_ROOT}" ]]; then
    export APACHE_DOCUMENT_ROOT="${APACHE_SERVER_ROOT}"
  fi
}

process_templates() {
  echo "Processing config templates..."
  _backwards_compatibility

  # 1. Apache Config
  _gotpl "vhost.conf.tmpl" "${APACHE_CONFDIR}/conf-available/vhost.conf"
  _gotpl "mpm.conf.tmpl" "${APACHE_CONFDIR}/conf-available/http-mpm.conf"
  _gotpl "mime.types.tmpl" "${APACHE_CONFDIR}/conf-available/mime.types"

  # 2. PHP Config
  php_ver_minor=$(echo "${PHP_VERSION}" | cut -d. -f1,2)
  export PHP_VER_MINOR="${php_ver_minor}"

  _gotpl "docker-php-ext-apcu.ini.tmpl" "${PHP_INI_DIR}/conf.d/docker-php-ext-apcu.ini"
  _gotpl "docker-php-${php_ver_minor}.ini.tmpl" "${PHP_INI_DIR}/conf.d/docker-php.ini"
  _gotpl "docker-php-ext-igbinary.ini.tmpl" "${PHP_INI_DIR}/conf.d/docker-php-ext-igbinary.ini"
  _gotpl "docker-php-ext-opcache.ini.tmpl" "${PHP_INI_DIR}/conf.d/docker-php-ext-opcache.ini"
  _gotpl "docker-php-ext-brotli.ini.tmpl" "${PHP_INI_DIR}/conf.d/docker-php-ext-brotli.ini"
}

disable_modules() {
  local dir="${PHP_INI_DIR}/conf.d"
  if [[ -n "${PHP_EXTENSIONS_DISABLE}" ]]; then
    IFS=',' read -r -a modules <<<"${PHP_EXTENSIONS_DISABLE}"
    for module in "${modules[@]}"; do
      # Buscamos el archivo .ini del módulo para borrarlo
      local target=$(find "${dir}" -name "*${module}.ini" -print -quit)
      if [[ -f "${target}" ]]; then
        rm "${target}" 2>/dev/null && echo "Disabled module: ${module}" || echo "Could not disable ${module}: Permission denied"
      fi
    done
  fi
}

# Ejecutar lógica
process_templates
disable_modules

# Lógica de ejecución final
if [[ "${1}" == "make" ]]; then
    exec "${@}" -f /usr/local/bin/actions.mk
elif [[ "${1}" == "apache2-foreground" || "${1}" == "httpd-foreground" ]]; then
    echo "Starting Apache..."
    exec /usr/local/bin/docker-php-entrypoint "${@}"
else
    exec "${@}"
fi