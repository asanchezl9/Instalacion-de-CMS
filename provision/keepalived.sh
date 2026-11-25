#!/usr/bin/env bash
# Script 6: Alta Disponibilidad en el balanceador con Keepalived (VRRP)
# Uso: keepalived.sh <MASTER|BACKUP> <PRIORIDAD>
set -e

export DEBIAN_FRONTEND=noninteractive

STATE="$1"
PRIORITY="$2"

# 1. Carga de variables de entorno
ENV_FILE="/vagrant/.env"
if [ ! -f "$ENV_FILE" ]; then
  ENV_FILE="/vagrant/.env.example"
fi

set -a
source <(tr -d '\r' < "$ENV_FILE")
set +a

# 2. Instalación de Keepalived
echo ">>> Instalando Keepalived en $(hostname) ($STATE, prioridad $PRIORITY)..."
apt-get update -y
apt-get install -y keepalived

# 3. Detectar automáticamente la interfaz de la red interna (192.168.10.x)
IFACE=$(ip -o -4 addr show | awk '/192\.168\.10\./ {print $2; exit}')

# 4. Configuración de Keepalived (VRRP + comprobación de Nginx)
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    script_user root
    enable_script_security
}

vrrp_script chk_nginx {
    script "/usr/bin/systemctl is-active --quiet nginx"
    interval 2
    weight 20
}

vrrp_instance VI_1 {
    state ${STATE}
    interface ${IFACE}
    virtual_router_id 51
    priority ${PRIORITY}
    advert_int 1

    authentication {
        auth_type PASS
        auth_pass LempHA26
    }

    virtual_ipaddress {
        ${IP_VIP}/24
    }

    track_script {
        chk_nginx
    }
}
EOF

# 5. Activar y reiniciar Keepalived
systemctl enable --now keepalived
systemctl restart keepalived

echo ">>> Keepalived configurado en $(hostname) sobre ${IFACE} con VIP ${IP_VIP}."