#!/usr/bin/env bash
# ============================================================================
# gerar-corcovado-wait.sh
# Aguarda a API Open-Meteo ficar disponível, gera o modelo do Corcovado,
# copia os arquivos para o diretório de saída e reinicia o nginx.
# ============================================================================
set -euo pipefail

LOG_FILE="/home/marceloclaro/Geomaker_site/scripts/corcovado-geracao.log"
MODERNIZED_DIR="/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master/modernized"
SCRIPTS_DIR="/home/marceloclaro/Geomaker_site/scripts"
SAIDAS_DIR="/home/marceloclaro/Geomaker_site/saidas/corcovado-160x96"
PLACE="Corcovado, Rio de Janeiro"
SIZE_KM=44

exec > "$LOG_FILE" 2>&1

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

log "=== INICIANDO GERACAO DO CORCOVADO ==="
log "Parametros: place=$PLACE, size=${SIZE_KM}km, resolucao=160×96"

# Wait for API
log "Aguardando API Open-Meteo..."
for i in $(seq 1 60); do
    STATUS=$(ruby -e "
        require 'net/http'
        uri = URI('https://api.open-meteo.com/v1/elevation?latitude=-22.9519&longitude=-43.2105')
        resp = Net::HTTP.get_response(uri)
        puts resp.code
    " 2>/dev/null || echo "erro")
    
    if [ "$STATUS" = "200" ]; then
        log "API OK na tentativa $i!"
        break
    fi
    
    if [ "$i" -eq 60 ]; then
        log "ERRO: API não respondeu após 60 tentativas (~5h)"
        exit 1
    fi
    
    sleep 300  # Check every 5 minutes
done

# Generate the model
log "Gerando modelo..."
bash "$SCRIPTS_DIR/gerar-corcovado.sh" --force

# Reload nginx to clear cache
log "Recarregando nginx..."
sudo nginx -s reload 2>/dev/null || true

log "=== GERACAO CONCLUIDA ==="
