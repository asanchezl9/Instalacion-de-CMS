#!/usr/bin/env bash
# Script 2: Balanceador de base de datos HAProxy (Capa 3)
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

# 2. Instalación de HAProxy
echo ">>> Instalando HAProxy en $(hostname)..."
apt-get update -y
apt-get install -y haproxy

# 3. Configuración de HAProxy en modo TCP para el clúster MariaDB Galera
echo ">>> Configurando HAProxy..."
cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

listen mariadb_galera
    bind ${IP_HAPROXY}:3306
    mode tcp
    balance roundrobin
    option mysql-check user ${HAPROXY_CHECK_USER}
    server db1 ${IP_DB1}:3306 check inter 2000 rise 2 fall 3
    server db2 ${IP_DB2}:3306 check inter 2000 rise 2 fall 3
    server db3 ${IP_DB3}:3306 check inter 2000 rise 2 fall 3
EOF

# 4. Validación y reinicio del servicio
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl enable --now haproxy
systemctl restart haproxy

echo ">>> HAProxy configurado correctamente en ${IP_HAPROXY}:3306."