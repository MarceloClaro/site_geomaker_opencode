#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/geomaker"
TOUCH_ROOT="$APP_ROOT/touchterrain"
VENV_ROOT="$APP_ROOT/venv"
BRIDGE_ROOT="$APP_ROOT/opencode-bridge"
BRIDGE_VENV="$APP_ROOT/opencode-bridge-venv"
DATA_ROOT="$APP_ROOT/data"
PID_FILE="$DATA_ROOT/touchterrain.pid"
BRIDGE_PID_FILE="$DATA_ROOT/opencode-bridge.pid"

if [[ ! -x "$VENV_ROOT/bin/gunicorn" ]]; then
  echo "A instalação não foi encontrada. Execute primeiro: bash wsl/setup.sh"
  exit 1
fi

if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl start nginx geomaker-touchterrain geomaker-opencode-bridge geomaker-touchterrain-watchdog.timer
else
  sudo service nginx start >/dev/null 2>&1 || sudo nginx
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "TouchTerrain já está em execução."
  else
    cd "$TOUCH_ROOT"
    nohup env \
      HOME="$HOME" \
      PYTHONPATH="$TOUCH_ROOT" \
      TOUCHTERRAIN_TMP_FOLDER="$DATA_ROOT/tmp" \
      TOUCHTERRAIN_DOWNLOADS_FOLDER="$DATA_ROOT/downloads" \
      TOUCHTERRAIN_PREVIEWS_FOLDER="$DATA_ROOT/previews" \
      TOUCHTERRAIN_GOOGLE_MAPS_KEY_FILE="$DATA_ROOT/GoogleMapsKey.txt" \
      TOUCHTERRAIN_GA_ID="" \
      TOUCHTERRAIN_MAX_CELLS="4000000" \
      "$VENV_ROOT/bin/gunicorn" --workers 1 --threads 2 --timeout 300 --bind 0.0.0.0:8081 touchterrain.server.TouchTerrain_app:app \
      >>"$DATA_ROOT/logs/touchterrain.log" 2>&1 &
    echo $! >"$PID_FILE"
  fi

  if [[ -x "$BRIDGE_VENV/bin/python" ]]; then
    if [[ -f "$BRIDGE_PID_FILE" ]] && kill -0 "$(cat "$BRIDGE_PID_FILE")" 2>/dev/null; then
      echo "Ponte OpenCode já está em execução."
    else
      cd "$BRIDGE_ROOT"
      nohup env \
        PORT="8082" HOST="127.0.0.1" \
        OPENCODE_MODEL="opencode/deepseek-v4-flash-free" \
        OPENCODE_AGENT="marceloclaro" \
        "$BRIDGE_VENV/bin/python" -m uvicorn server:app --host 127.0.0.1 --port 8082 \
        >>"$DATA_ROOT/logs/opencode-bridge.log" 2>&1 &
      echo $! >"$BRIDGE_PID_FILE"
    fi
  fi
fi

echo "Geomaker iniciado: http://localhost:8080"
