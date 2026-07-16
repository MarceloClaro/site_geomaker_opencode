#!/usr/bin/env bash
set -Eeuo pipefail
APP_ROOT="/opt/geomaker"
VENV_ROOT="$APP_ROOT/venv"
TOUCH_ROOT="$APP_ROOT/touchterrain"

if [[ ! -x "$VENV_ROOT/bin/earthengine" ]]; then
  echo "Earth Engine não instalado. Execute primeiro: bash wsl/setup.sh"
  exit 1
fi

echo "O Earth Engine exige um projeto Google Cloud registrado para uso da API."
read -r -p "ID do projeto Google Cloud: " EE_PROJECT
if [[ -z "$EE_PROJECT" ]]; then
  echo "O ID do projeto é obrigatório."
  exit 1
fi

echo "A autenticação abrirá ou exibirá um endereço Google."
echo "Entre com a conta autorizada para o Earth Engine e conclua a permissão."
"$VENV_ROOT/bin/earthengine" authenticate --auth_mode=localhost
"$VENV_ROOT/bin/earthengine" set_project "$EE_PROJECT"

echo "Validando a credencial..."
EE_PROJECT="$EE_PROJECT" HOME="$HOME" PYTHONPATH="$TOUCH_ROOT" "$VENV_ROOT/bin/python" - <<'PY'
import os
import ee
ee.Initialize(project=os.environ["EE_PROJECT"])
print("Earth Engine autenticado com sucesso.")
PY

if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl restart geomaker-touchterrain
else
  bash "$APP_ROOT/installer/stop.sh"
  bash "$APP_ROOT/installer/start.sh"
fi

echo "Pronto. Abra http://localhost:8080/laboratorio.html"
