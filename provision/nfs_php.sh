#!/usr/bin/env bash
# Script 3: Servidor NFS, PHP-FPM (TCP) y WordPress con WP-CLI (Capa 2)
set -e

export DEBIAN_FRONTEND=noninteractive

# 1. Carga de variables de entorno
ENV_FILE="/vagrant/.env"
if [ ! -f "$ENV_FILE" ]; then
  ENV_FILE="/vagrant/.env.example"
fi

set -a
source <(tr -d '\r' < "$ENV_FILE")
set +a

WP_PATH="/var/www/html"

# 2. Instalación de NFS Server, PHP-FPM, extensiones de WordPress y cliente MariaDB
echo ">>> Instalando NFS Server, PHP-FPM y dependencias en $(hostname)..."
apt-get update -y
apt-get install -y \
  nfs-kernel-server \
  mariadb-client \
  php-fpm \
  php-cli \
  php-mysql \
  php-curl \
  php-gd \
  php-intl \
  php-mbstring \
  php-soap \
  php-xml \
  php-zip \
  curl \
  unzip

# 3. Configuración de PHP-FPM por socket TCP restringido a los dos servidores web
echo ">>> Configurando PHP-FPM en ${IP_NFS}:9000..."
PHP_POOL="/etc/php/8.2/fpm/pool.d/www.conf"
PHP_INI="/etc/php/8.2/fpm/php.ini"

sed -i "s|^listen = .*|listen = ${IP_NFS}:9000|" "$PHP_POOL"
if grep -q "^;\?listen.allowed_clients" "$PHP_POOL"; then
  sed -i "s|^;\?listen.allowed_clients = .*|listen.allowed_clients = ${IP_WEB1},${IP_WEB2}|" "$PHP_POOL"
else
  echo "listen.allowed_clients = ${IP_WEB1},${IP_WEB2}" >> "$PHP_POOL"
fi

sed -i 's/^;\?cgi\.fix_pathinfo=.*/cgi.fix_pathinfo=0/' "$PHP_INI"
sed -i 's/^upload_max_filesize\s*=.*/upload_max_filesize = 64M/' "$PHP_INI"
sed -i 's/^post_max_size\s*=.*/post_max_size = 64M/' "$PHP_INI"

systemctl enable --now php8.2-fpm
systemctl restart php8.2-fpm

# 4. Instalación de WP-CLI y despliegue de WordPress conectado a HAProxy
echo ">>> Instalando WP-CLI y configurando WordPress..."
mkdir -p "$WP_PATH"

if ! command -v wp >/dev/null 2>&1; then
  curl -sSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
  chmod +x /usr/local/bin/wp
fi

if [ ! -f "$WP_PATH/wp-includes/version.php" ]; then
  wp core download --path="$WP_PATH" --allow-root
fi

if [ ! -f "$WP_PATH/wp-config.php" ]; then
  wp config create \
    --path="$WP_PATH" \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASS" \
    --dbhost="${IP_HAPROXY}:3306" \
    --locale="$WP_LOCALE" \
    --allow-root

  # Ajustes para trabajar detrás de un balanceador de carga (proxy inverso)
  wp config set WP_HOME "$WP_URL" --path="$WP_PATH" --allow-root
  wp config set WP_SITEURL "$WP_URL" --path="$WP_PATH" --allow-root
fi

if ! wp core is-installed --path="$WP_PATH" --allow-root; then
  wp core install \
    --path="$WP_PATH" \
    --url="$WP_URL" \
    --title="$WP_TITLE" \
    --admin_user="$WP_ADMIN_USER" \
    --admin_password="$WP_ADMIN_PASS" \
    --admin_email="$WP_ADMIN_EMAIL" \
    --skip-email \
    --allow-root
fi

wp language core install "$WP_LOCALE" --activate --path="$WP_PATH" --allow-root || true
wp rewrite structure '/%postname%/' --path="$WP_PATH" --allow-root
wp rewrite flush --path="$WP_PATH" --allow-root

# Tema personalizado distinto al de por defecto
if ! wp theme is-installed "$WP_THEME" --path="$WP_PATH" --allow-root; then
  wp theme install "$WP_THEME" --activate --path="$WP_PATH" --allow-root
else
  wp theme activate "$WP_THEME" --path="$WP_PATH" --allow-root
fi

# Entrada propia inicial
if [ -z "$(wp post list --post_type=post --name=bienvenida-ha --format=ids --path="$WP_PATH" --allow-root)" ]; then
  wp post create \
    --post_type=post \
    --post_title="Despliegue en Alta Disponibilidad de 4 capas" \
    --post_name="bienvenida-ha" \
    --post_content="Entrada inicial generada automáticamente sobre la infraestructura LEMP en Alta Disponibilidad con MariaDB Galera, HAProxy, NFS y Nginx." \
    --post_status=publish \
    --path="$WP_PATH" \
    --allow-root
fi

# Propietario y permisos correctos (www-data)
chown -R www-data:www-data "$WP_PATH"
find "$WP_PATH" -type d -exec chmod 755 {} \;
find "$WP_PATH" -type f -exec chmod 644 {} \;
chmod 640 "$WP_PATH/wp-config.php"

# 5. Exportación por NFS únicamente a los dos servidores web con root_squash
echo ">>> Configurando exportación NFS en /etc/exports..."
echo "${WP_PATH} ${IP_WEB1}(rw,sync,no_subtree_check,root_squash) ${IP_WEB2}(rw,sync,no_subtree_check,root_squash)" > /etc/exports

exportfs -ra
systemctl enable --now nfs-kernel-server
systemctl restart nfs-kernel-server

echo ">>> Servidor NFS, PHP-FPM y WordPress configurados correctamente."