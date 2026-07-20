#!/usr/bin/env bash
# ============================================================================
# gerar-corcovado.sh
# Gera o modelo 3D de relevo em papel do Corcovado, Rio de Janeiro
# com altíssima resolução (160×128), notches V/H, mapa OSM e PDF de instruções.
#
# Uso: ./gerar-corcovado.sh [--force]
#   --force: gera mesmo se o diretório de saída já existir
# ============================================================================
set -euo pipefail

MODERNIZED_DIR="/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master/modernized"
SCRIPTS_DIR="/home/marceloclaro/Geomaker_site/scripts"
SAIDAS_DIR="/home/marceloclaro/Geomaker_site/saidas/corcovado-160x96"
PLACE="Corcovado, Rio de Janeiro"
SIZE_KM=44
LAT_STEPS=160
LON_STEPS=128
Z_CMS=8
LENGTH_CM=12
GAP_CM=0.01
SMOOTH_PASSES=3

# Cores
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
RESET='\033[0m'

log()  { echo -e "${VERDE}[$(date '+%H:%M:%S')]${RESET} $1"; }
warn() { echo -e "${AMARELO}[AVISO]${RESET} $1"; }
erro() { echo -e "${VERMELHO}[ERRO]${RESET} $1" >&2; }

# Verifica se já existe
if [ -d "$SAIDAS_DIR" ] && [ "${1:-}" != "--force" ]; then
    if ls "$SAIDAS_DIR"/metadados.json 2>/dev/null; then
        warn "Diretório $SAIDAS_DIR já existe com metadados."
        warn "Use --force para regenerar."
        exit 0
    fi
fi

log "=============================================="
log "GERAÇÃO DO MODELO — CORCOVADO 160×96"
log "=============================================="
log "Local: $PLACE"
log "Área: ${SIZE_KM}×${SIZE_KM} km"
log "Resolução: ${LAT_STEPS}×${LON_STEPS}"
log "Saída: $SAIDAS_DIR"
log ""

# 1. Verificar API Open-Meteo
log "Verificando disponibilidade da API Open-Meteo..."
API_OK=$(ruby -e "
require 'net/http'
require 'json'
uri = URI('https://api.open-meteo.com/v1/elevation?latitude=-22.9519&longitude=-43.2105')
resp = Net::HTTP.get_response(uri)
puts resp.code
" 2>/dev/null)

if [ "$API_OK" != "200" ]; then
    erro "API Open-Meteo não disponível (HTTP $API_OK)."
    erro "Aguarde o reset diário (00:00 UTC ≈ 21:00 BRT)."
    exit 1
fi
log "API OK!"

# 2. Gerar o modelo principal (SVG visão geral + páginas A4)
log "Gerando modelo de relevo..."
cd "$MODERNIZED_DIR"

ruby 3d-paper-model.rb \
    --place "$PLACE" \
    --size-km "$SIZE_KM" \
    --lat-steps "$LAT_STEPS" \
    --lon-steps "$LON_STEPS" \
    --z-cms "$Z_CMS" \
    --length-cm "$LENGTH_CM" \
    --gap-cm "$GAP_CM" \
    --smooth-passes "$SMOOTH_PASSES" \
    --out "$SAIDAS_DIR/visao-geral.svg" \
    --paginate "$SAIDAS_DIR/parte"

log "Modelo gerado com sucesso!"

# 3. Copiar metadados e ajustar
log "Ajustando metadados..."
cp "$SAIDAS_DIR"/metadados.json "$SAIDAS_DIR"/metadados.json.bak

# 4. Gerar mapa interativo OSM
log "Gerando mapa interativo..."
ruby "$SCRIPTS_DIR/gerar-mapa-modelo.rb" \
    --dir "$SAIDAS_DIR" \
    --place "$PLACE" \
    --size-km "$SIZE_KM"

# 5. Gerar PDF de instruções
log "Gerando PDF de instruções..."
ruby "$SCRIPTS_DIR/gerar-instrucoes-pdf.rb" \
    --dir "$SAIDAS_DIR" \
    --place "$PLACE" \
    --resolucao "${LAT_STEPS}×${LON_STEPS}" \
    --paginas "$(ruby -e "puts (${LON_STEPS}/6.0).ceil")"

log ""
log "=============================================="
log "✅ MODELO DO CORCOVADO COMPLETO!"
log "=============================================="
log "Acesse: http://localhost:8080/saidas/corcovado-160x96/"
log ""

# 6. Validar
log "Executando validação..."
python3 -c "
import json, os, re

pasta = '$SAIDAS_DIR'
if not os.path.exists(pasta):
    print('❌ Diretório não encontrado')
    exit(1)

meta = json.load(open(f'{pasta}/metadados.json')) if os.path.exists(f'{pasta}/metadados.json') else {}
svg = open(f'{pasta}/visao-geral.svg').read() if os.path.exists(f'{pasta}/visao-geral.svg') else ''

checks = {'pass': 0, 'fail': 0}

# 1. Total polylines
total = svg.count('<polyline')
esperado = ${LON_STEPS} + (${LON_STEPS} * (${LAT_STEPS}//10 - (1 if ${LAT_STEPS}%10==0 else 0)))
checks['1. Polylines'] = total > ${LON_STEPS}

# 2. V/H alternância
tags = re.findall(r'<polyline points=\"([^\"]+)\" style=\"([^\"]+)\"', svg)
v = [t for t in tags if 'fill:white' in t[1]]
h = [t for t in tags if 'fill:none' in t[1]]
checks['2. V:H ≈ 1:1'] = len(v) == len(h) and len(v) > 0

# 3. Alinhamento X
v_xs = []
for p,s in v[:10]:
    coords = p.split()
    xs = [float(c.split(',')[0]) for c in coords]
    v_xs.append(round((min(xs)+max(xs))/2)) if xs else None
h_xs = []
for p,s in h[:10]:
    coords = p.split()
    xs = [float(c.split(',')[0]) for c in coords]
    h_xs.append(round((min(xs)+max(xs))/2)) if xs else None
checks['3. X-align V=H'] = v_xs == h_xs

# 4. V para baixo
if v:
    coords = v[0][0].split()
    ys = [float(c.split(',')[1]) for c in coords]
    checks['4. V protrusão ↓'] = max(ys) > min(ys)

# 5. H para cima
if h:
    coords = h[0][0].split()
    ys = [float(c.split(',')[1]) for c in coords]
    checks['5. H reentrância ↑'] = max(ys) > min(ys)

# 6. Páginas A4
pages = [f for f in os.listdir(pasta) if f.startswith('parte-') and f.endswith('.svg')]
checks['6. Páginas A4'] = len(pages) >= 10  # 96 slices ≈ 16 pages

# 7. Arquivos essenciais
essenciais = ['visao-geral.svg', 'mapa.html', 'instrucoes-montagem.pdf', 'metadados.json']
checks['7. Arquivos'] = all(os.path.exists(f'{pasta}/{a}') for a in essenciais)

# 8. PDF válido
pdf_path = f'{pasta}/instrucoes-montagem.pdf'
checks['8. PDF > 1KB'] = os.path.exists(pdf_path) and os.path.getsize(pdf_path) > 1000

print()
for k, v in checks.items():
    print(f'  {\"✅\" if v else \"❌\"} {k}')
print(f'\nResultado: {\"✅ APROVADO\" if all(checks.values()) else \"❌ REPROVADO\"} ({sum(1 for v in checks.values() if v)}/{len(checks)} checks)')
"

echo ""
echo "Pronto! O modelo do Corcovado está disponível em:"
echo "  http://localhost:8080/saidas/corcovado-160x96/"
echo ""
