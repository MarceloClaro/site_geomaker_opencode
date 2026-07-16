#!/usr/bin/env bash
set -Eeuo pipefail
KEY_FILE="/opt/geomaker/data/GoogleMapsKey.txt"

read -r -s -p "Cole a chave da API Google Maps (a entrada ficará oculta): " MAPS_KEY
echo
if [[ -z "$MAPS_KEY" ]]; then
  echo "Nenhuma chave informada. Nada foi alterado."
  exit 1
fi

printf '%s' "$MAPS_KEY" >"$KEY_FILE"
chmod 600 "$KEY_FILE"
unset MAPS_KEY

if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl restart geomaker-touchterrain
else
  bash /opt/geomaker/installer/stop.sh
  bash /opt/geomaker/installer/start.sh
fi

echo "Chave configurada sem ser exibida nos logs."
