#!/bin/bash
# gerar-modelo.sh — Regenera o modelo de relevo em papel 3D
# no diretório saida-geomaker/ (estilo polana/).
#
# Uso:
#   ./saida-geomaker/gerar-modelo.sh
#
# Gera:
#   parte-a.svg .. parte-d.svg  (páginas individuais A4)
#   localizadores.svg           (mapa de calor + índice)
#   todas-as-partes.svg         (concatenação)

set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"

echo "🔄 Regenerando modelo na raiz: $ROOT"
echo "   Saída: $DIR"
echo ""

cd "$ROOT"
node --experimental-modules "$DIR/gerar-modelo.cjs" 2>&1
echo ""
echo "🔗 Acessível em Windows via:"
echo "   \\\\wsl.localhost\\Ubuntu$(echo "$DIR" | sed 's|/|\\|g')"
