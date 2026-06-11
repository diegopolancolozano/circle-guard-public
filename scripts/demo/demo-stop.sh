#!/usr/bin/env bash
# demo-stop.sh — Para todos los port-forwards de la demo
SERVER="root@104.248.109.57"
echo "Parando port-forwards en $SERVER..."
ssh "$SERVER" "pkill -f 'kubectl.*port-forward' 2>/dev/null && echo 'Detenidos.' || echo 'No había procesos activos.'"
