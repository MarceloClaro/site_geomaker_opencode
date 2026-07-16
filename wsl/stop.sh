#!/usr/bin/env bash
set -Eeuo pipefail
DATA_ROOT="/opt/geomaker/data"
PID_FILE="$DATA_ROOT/touchterrain.pid"
BRIDGE_PID_FILE="$DATA_ROOT/opencode-bridge.pid"

if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl stop geomaker-touchterrain-watchdog.timer geomaker-opencode-bridge geomaker-touchterrain geomaker-tunnel nginx 2>/dev/null || true
else
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
  fi
  if [[ -f "$BRIDGE_PID_FILE" ]] && kill -0 "$(cat "$BRIDGE_PID_FILE")" 2>/dev/null; then
    kill "$(cat "$BRIDGE_PID_FILE")"
    rm -f "$BRIDGE_PID_FILE"
  fi
  sudo service nginx stop >/dev/null 2>&1 || true
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/expor-publicamente.sh" stop 2>/dev/null || true

echo "Serviços do Geomaker interrompidos."
