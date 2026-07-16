#!/usr/bin/env bash
# Atualiza somente os arquivos públicos a partir de outro ZIP do Museu Geomaker.
set -Eeuo pipefail
ZIP_PATH="${1:-}"
SITE_ROOT="/opt/geomaker/site"

if [[ -z "$ZIP_PATH" || ! -f "$ZIP_PATH" ]]; then
  echo "Uso: bash /opt/geomaker/installer/receber-site.sh /caminho/Geomaker_site.zip"
  exit 1
fi

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
unzip -q "$ZIP_PATH" -d "$TEMP_DIR"

if [[ -f "$TEMP_DIR/index.html" ]]; then
  SOURCE_ROOT="$TEMP_DIR"
else
  ROOT_INDEX="$(find "$TEMP_DIR" -mindepth 2 -maxdepth 2 -type f -name index.html -print -quit)"
  if [[ -z "$ROOT_INDEX" ]]; then
    echo "ZIP inválido: index.html principal não encontrado."
    exit 1
  fi
  SOURCE_ROOT="$(dirname "$ROOT_INDEX")"
fi

if [[ ! -f "$SOURCE_ROOT/assets/site.js" ]]; then
  echo "ZIP inválido: assets/site.js não encontrado."
  exit 1
fi

rsync -a --exclude='wsl' --exclude='node_modules' "$SOURCE_ROOT/" "$SITE_ROOT/"
sudo nginx -t
if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl reload nginx
else
  sudo service nginx reload
fi

echo "Site atualizado em $SITE_ROOT"
echo "Abra: http://localhost:8080"
