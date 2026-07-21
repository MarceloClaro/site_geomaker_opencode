#!/usr/bin/env bash
# ============================================================================
# fetch-corcovado-real.sh
# Baixa dados de elevação REAIS da Open-Meteo para o Corcovado HD (240×192)
# e salva no cache. Roda em background (~90 min devido a rate limits).
#
# O cache interpolado continua sendo usado até o download real completar.
# Quando este script terminar, o cache será automaticamente substituído
# pelos dados reais na próxima geração do modelo.
#
# Uso: nohup bash fetch-corcovado-real.sh &
#       tail -f fetch-corcovado-real.log
# ============================================================================
set -euo pipefail

LOG="/home/marceloclaro/Geomaker_site/scripts/fetch-corcovado-real.log"
CACHE_DIR="/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master/modernized/.elevation_cache"
INTERPOLADO="$CACHE_DIR/7cae78782dfa447b582649e1742ca64848b009ce1c88f04ca0c7905cfa6c8c6f.json"

exec > "$LOG" 2>&1

echo "[$(date)] Iniciando download real Open-Meteo para Corcovado 240×192..."
echo "[$(date)] 46.080 pontos em lotes de 96 (480 lotes)"

# Remove o cache interpolado para forçar download real
if [ -f "$INTERPOLADO" ]; then
    echo "[$(date)] Removendo cache interpolado para forçar fetch real..."
    mv "$INTERPOLADO" "${INTERPOLADO}.bak"
    echo "[$(date)] Cache interpolado movido para .bak"
fi

# Executa o fetch (vai ser lento devido a rate limits)
cd /home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master/modernized

ruby -e "
require_relative 'lib/elevation_provider'
require_relative 'lib/elevation_cache'
require 'json'

lat0 = -23.149578458498024
lon0 = -43.425199402537
lat1 = -22.754321541501977
lon1 = -42.995960597463004
lat_steps = 240
lon_steps = 192

script_dir = __dir__
cache_dir = File.join(script_dir, '.elevation_cache')

# Check if real cache already exists
key = ElevationCache.cache_key(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps)
puts \"Cache key: #{key}\"

cached = ElevationCache.load(key, script_dir: script_dir)
if cached
  puts \"Cache real já existe! Verificando origem...\"
  data = JSON.parse(File.read(File.join(cache_dir, \"#{key}.json\")))
  puts \"Fonte: #{data['created_at']}\"
  exit 0
end

puts \"Cache MISS. Iniciando download real (pode levar 60-90 min)...\"
puts \"Início: #{Time.now}\"

elevations = ElevationProvider.fetch_grid(
  lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1,
  lat_steps: lat_steps, lon_steps: lon_steps,
  cache: script_dir
)

puts \"Download concluído! #{elevations.flatten.size} pontos\"
puts \"Término: #{Time.now}\"
puts \"Elevação: #{elevations.flatten.min}..#{elevations.flatten.max} m\"
"

# Limpeza do backup
if [ -f "${INTERPOLADO}.bak" ] && [ -f "$INTERPOLADO" ]; then
    echo "[$(date)] Cache real salvo. Removendo backup interpolado..."
    rm -f "${INTERPOLADO}.bak"
fi

echo "[$(date)] ✅ Download real concluído! Cache atualizado."
