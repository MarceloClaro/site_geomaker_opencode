#!/usr/bin/env bash
# Executa o modo standalone com um JSON gerado pelo Preparador CAGEO.
set -Eeuo pipefail
CONFIG_PATH="${1:-}"
APP_ROOT="/opt/geomaker"
TOUCH_ROOT="$APP_ROOT/touchterrain"
VENV_ROOT="$APP_ROOT/venv"
EXPORT_ROOT="$APP_ROOT/data/exports"

if [[ -z "$CONFIG_PATH" || ! -f "$CONFIG_PATH" ]]; then
  echo "Uso: bash /opt/geomaker/installer/criar-modelo.sh /caminho/configuracao.json"
  exit 1
fi

CONFIG_PATH="$(realpath "$CONFIG_PATH")"
JOB_DIR="$EXPORT_ROOT/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$JOB_DIR"
cp "$CONFIG_PATH" "$JOB_DIR/configuracao.json"
cd "$JOB_DIR"

echo "Processando modelo em $JOB_DIR ..."
HOME="$HOME" PYTHONPATH="$TOUCH_ROOT" "$VENV_ROOT/bin/python" "$TOUCH_ROOT/TouchTerrain_standalone.py" "$JOB_DIR/configuracao.json"

echo "Arquivos gerados:"
find "$JOB_DIR" -maxdepth 2 -type f -printf '  %p\n'
