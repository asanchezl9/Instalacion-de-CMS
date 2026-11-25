#!/usr/bin/env bash
# Script 5: Balanceador de carga Nginx (Capa 1 - Único punto de entrada)
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

# 2. Instalación de Nginx
echo ">>> Instalando Nginx en $(hostname)..."
apt-get update -y
apt-get install -y nginx

# 3. Formato de log personalizado con el servidor backend elegido ($upstream_addr)
echo ">>> Configurando formato de log y límite de subida..."
cat > /etc/nginx/conf.d/lb_logging.conf <<'EOF'
log_format upstream_log '$remote_addr - [$time_local] "$request" '
                        '$status $body_bytes_sent '
                        'upstream="$upstream_addr" '
                        'rt=$request_time';

client_max_body_size 64M;
EOF

# 4. Configuración del upstream y proxy inverso hacia serverweb1 y serverweb2
echo ">>> Configurando balanceo de carga en Nginx..."
cat > /etc/nginx/sites-available/default <<EOF
upstream wordpress_backend {
    server ${IP_WEB1}:80 max_fails=2 fail_timeout=10s;
    server ${IP_WEB2}:80 max_fails=2 fail_timeout=10s;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    access_log /var/log/nginx/access.log upstream_log;

    location / {
        proxy_pass http://wordpress_backend;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;

        # Cabeceras necesarias para WordPress y para registrar la IP real en los backends
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 5. Validación y reinicio de Nginx
nginx -t
systemctl enable --now nginx
systemctl restart nginx

echo ">>> Balanceador Nginx configurado correctamente."