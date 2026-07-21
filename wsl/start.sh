#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/geomaker"
TOUCH_ROOT="$APP_ROOT/touchterrain"
VENV_ROOT="$APP_ROOT/venv"
DATA_ROOT="$APP_ROOT/data"
PID_FILE="$DATA_ROOT/touchterrain.pid"

if [[ ! -x "$VENV_ROOT/bin/gunicorn" ]]; then
  echo "A instalação não foi encontrada. Execute primeiro: bash wsl/setup.sh"
  exit 1
fi

if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl start nginx geomaker-touchterrain
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
fi

echo "Geomaker iniciado: http://localhost:8080"
