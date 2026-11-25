#!/usr/bin/env bash
# Script 4: Servidores web Nginx + cliente NFS (Capa 2)
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
SERVER_NAME_ID="$(hostname)"

# 2. Instalación de Nginx y cliente NFS
echo ">>> Instalando Nginx y cliente NFS en ${SERVER_NAME_ID}..."
apt-get update -y
apt-get install -y nginx nfs-common

# 3. Montaje persistente de WordPress por NFS (idempotente)
echo ">>> Montando ${IP_NFS}:${WP_PATH} en ${WP_PATH}..."
mkdir -p "$WP_PATH"

FSTAB_LINE="${IP_NFS}:${WP_PATH} ${WP_PATH} nfs defaults,_netdev 0 0"
if ! grep -qs "^${IP_NFS}:${WP_PATH} " /etc/fstab; then
  echo "$FSTAB_LINE" >> /etc/fstab
fi

mountpoint -q "$WP_PATH" || mount -a

# 4. Configuración de Nginx (PHP-FPM remoto por TCP, IP real y cabecera de hostname)
echo ">>> Configurando Nginx en ${SERVER_NAME_ID}..."
echo "client_max_body_size 64M;" > /etc/nginx/conf.d/uploads.conf

cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root ${WP_PATH};
    index index.php index.html index.htm;
    server_name _;

    # Registrar en los logs la IP real del visitante y no la del balanceador
    set_real_ip_from ${IP_LB};
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    # Cabecera HTTP indicando qué servidor web atiende la petición
    add_header X-Served-By "${SERVER_NAME_ID}" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass ${IP_NFS}:9000;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# 5. Validación y reinicio de Nginx
nginx -t
systemctl enable --now nginx
systemctl restart nginx

echo ">>> Servidor web ${SERVER_NAME_ID} configurado correctamente."