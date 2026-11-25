#!/usr/bin/env bash
# Script 1: Clúster MariaDB Galera (Capa 4 - Datos)
# Uso: galera.sh <IP_NODO> <bootstrap|join>
set -e

export DEBIAN_FRONTEND=noninteractive

NODE_IP="$1"
ROLE="$2"

# 1. Carga de variables de entorno
ENV_FILE="/vagrant/.env"
if [ ! -f "$ENV_FILE" ]; then
  ENV_FILE="/vagrant/.env.example"
fi

set -a
source <(tr -d '\r' < "$ENV_FILE")
set +a

# 2. Instalación de MariaDB Server, Galera 4 y rsync
echo ">>> Instalando MariaDB y Galera en $(hostname) ($NODE_IP)..."
apt-get update -y
apt-get install -y mariadb-server galera-4 rsync

# 3. Configuración de MariaDB en red interna y parámetros de Galera
echo ">>> Configurando Galera Cluster..."
cat > /etc/mysql/mariadb.conf.d/60-galera.cnf << EOF
[mysqld]
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2
bind-address=${NODE_IP}

wsrep_on=ON
wsrep_provider=/usr/lib/galera/libgalera_smm.so
wsrep_cluster_name="${CLUSTER_NAME}"
wsrep_cluster_address="gcomm://${IP_DB1},${IP_DB2},${IP_DB3}"
wsrep_node_address="${NODE_IP}"
wsrep_node_name="$(hostname)"
wsrep_sst_method=rsync
EOF

# 4. Arranque del clúster (idempotente)
CLUSTER_SIZE=$(mariadb -Nse "SHOW STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null | awk '{print $2}' || echo "0")

if [ "$ROLE" = "bootstrap" ]; then
  if [ "$CLUSTER_SIZE" -eq 0 ]; then
    echo ">>> Inicializando el clúster Galera (bootstrap)..."
    systemctl stop mariadb || true
    galera_new_cluster
  else
    echo ">>> El clúster ya está activo en este nodo (tamaño: $CLUSTER_SIZE)."
  fi

  # Creación de la BD y usuarios restringidos exclusivamente a HAProxy
  echo ">>> Creando base de datos y usuarios restringidos a HAProxy ($IP_HAPROXY)..."
  mariadb -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '${DB_USER}'@'${IP_HAPROXY}' IDENTIFIED BY '${DB_PASS}';
  ALTER USER '${DB_USER}'@'${IP_HAPROXY}' IDENTIFIED BY '${DB_PASS}';
  GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'${IP_HAPROXY}';
  CREATE USER IF NOT EXISTS '${HAPROXY_CHECK_USER}'@'${IP_HAPROXY}';
  FLUSH PRIVILEGES;"
else
  if [ "$CLUSTER_SIZE" -lt 2 ]; then
    echo ">>> Uniendo $(hostname) al clúster Galera..."
    systemctl stop mariadb || true
    systemctl start mariadb
  else
    echo ">>> El nodo ya forma parte del clúster (tamaño: $CLUSTER_SIZE)."
  fi
fi

systemctl enable mariadb
echo ">>> Nodo Galera $(hostname) configurado correctamente."