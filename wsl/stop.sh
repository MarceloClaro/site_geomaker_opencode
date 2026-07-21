#!/usr/bin/env bash
set -Eeuo pipefail
DATA_ROOT="/opt/geomaker/data"
PID_FILE="$DATA_ROOT/touchterrain.pid"

if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl stop geomaker-touchterrain geomaker-tunnel nginx
else
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
  fi
  sudo service nginx stop >/dev/null 2>&1 || true
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/expor-publicamente.sh" stop 2>/dev/null || true

echo "Serviços do Geomaker interrompidos."
