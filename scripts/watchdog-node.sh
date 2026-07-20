#!/usr/bin/env bash
# ============================================================================
# watchdog-node.sh
# Mantém o Node server (relevo-server.cjs) rodando.
# Verifica a cada 30s se está vivo; se não, reinicia.
# Rode em background: nohup bash watchdog-node.sh &
# ============================================================================
set -euo pipefail

SERVER_CMD="node /opt/geomaker/site/relevo-server.cjs"
SERVER_LOG="/home/marceloclaro/Geomaker_site/scripts/relevo-server.log"
CHECK_URL="http://127.0.0.1:8083/api/relevo/status"

while true; do
    if ! curl -s --max-time 3 "$CHECK_URL" > /dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Node server OFF — reiniciando..."
        fuser -k 8083/tcp 2>/dev/null || true
        sleep 1
        nohup $SERVER_CMD >> "$SERVER_LOG" 2>&1 &
        sleep 2
        if curl -s --max-time 3 "$CHECK_URL" > /dev/null 2>&1; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Reiniciado com sucesso"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Falha na reinicialização"
        fi
    fi
    sleep 30
done
