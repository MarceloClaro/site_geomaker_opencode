#!/usr/bin/env bash
# Instala Museu Geomaker + Ancient Earth + TouchTerrain localmente no WSL Ubuntu.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_ROOT="/opt/geomaker"
SITE_ROOT="$APP_ROOT/site"
TOUCH_ROOT="$APP_ROOT/touchterrain"
VENV_ROOT="$APP_ROOT/venv"
DATA_ROOT="$APP_ROOT/data"
INSTALLER_ROOT="$APP_ROOT/installer"
CURRENT_USER="${USER}"
CURRENT_GROUP="$(id -gn)"

on_error() {
  echo
  echo "Falha na linha $1. Consulte as mensagens acima e execute novamente: bash wsl/setup.sh"
}
trap 'on_error $LINENO' ERR

if [[ "$EUID" -eq 0 ]]; then
  echo "Execute como usuário normal, sem colocar sudo antes do script. O instalador pedirá sudo quando necessário."
  exit 1
fi

if ! grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  echo "Aviso: o ambiente não parece ser WSL. A instalação continuará como Ubuntu/Debian comum."
fi

if [[ ! -f "$PACKAGE_ROOT/index.html" || ! -d "$SCRIPT_DIR/vendor/TouchTerrain_for_CAGEO" ]]; then
  echo "Pacote incompleto. Extraia o ZIP inteiro e execute este arquivo dentro da pasta extraída."
  exit 1
fi

echo "[1/8] Atualizando pacotes do Ubuntu..."
sudo -v
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nginx unzip rsync curl ca-certificates build-essential \
  python3 python3-venv python3-pip python3-dev \
  gdal-bin libgdal-dev python3-gdal python3-numpy python3-scipy python3-pil

echo "[2/8] Criando a instalação em $APP_ROOT..."
sudo install -d -o "$CURRENT_USER" -g "$CURRENT_GROUP" "$APP_ROOT" "$SITE_ROOT" "$TOUCH_ROOT" "$VENV_ROOT" "$DATA_ROOT" "$DATA_ROOT/tmp" "$DATA_ROOT/downloads" "$DATA_ROOT/previews" "$DATA_ROOT/exports" "$DATA_ROOT/logs" "$INSTALLER_ROOT"

echo "[3/8] Instalando os arquivos do site e da Terra Antiga..."
rsync -a --exclude='wsl' --exclude='node_modules' "$PACKAGE_ROOT/" "$SITE_ROOT/"
rsync -a "$SCRIPT_DIR/vendor/TouchTerrain_for_CAGEO/" "$TOUCH_ROOT/"
rsync -a --exclude='vendor' "$SCRIPT_DIR/" "$INSTALLER_ROOT/"
chmod +x "$INSTALLER_ROOT"/*.sh

echo "[4/8] Criando o ambiente Python do TouchTerrain..."
if [[ ! -x "$VENV_ROOT/bin/python" ]]; then
  python3 -m venv --system-site-packages "$VENV_ROOT"
fi
"$VENV_ROOT/bin/python" -m pip install --upgrade pip wheel setuptools
"$VENV_ROOT/bin/python" -m pip install -r "$INSTALLER_ROOT/requirements-wsl.txt"

echo "[5/8] Validando Python, GDAL e o código empacotado..."
PYTHONPATH="$TOUCH_ROOT" "$VENV_ROOT/bin/python" - <<'PY'
from osgeo import gdal
import ee
import flask
import gunicorn
from touchterrain.common import TouchTerrainEarthEngine
print("GDAL:", gdal.VersionInfo())
print("Earth Engine:", getattr(ee, "__version__", "instalado"))
print("Flask:", getattr(flask, "__version__", "instalado"))
print("TouchTerrain: importação concluída")
PY

touch "$DATA_ROOT/GoogleMapsKey.txt"
chmod 600 "$DATA_ROOT/GoogleMapsKey.txt"

echo "[6/8] Configurando o serviço local TouchTerrain na porta 8081..."
sudo tee /etc/systemd/system/geomaker-touchterrain.service >/dev/null <<EOF
[Unit]
Description=Museu Geomaker - TouchTerrain local
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_GROUP
WorkingDirectory=$TOUCH_ROOT
Environment=HOME=$HOME
Environment=PYTHONPATH=$TOUCH_ROOT
Environment=TOUCHTERRAIN_TMP_FOLDER=$DATA_ROOT/tmp
Environment=TOUCHTERRAIN_DOWNLOADS_FOLDER=$DATA_ROOT/downloads
Environment=TOUCHTERRAIN_PREVIEWS_FOLDER=$DATA_ROOT/previews
Environment=TOUCHTERRAIN_GOOGLE_MAPS_KEY_FILE=$DATA_ROOT/GoogleMapsKey.txt
Environment=TOUCHTERRAIN_GA_ID=
Environment=TOUCHTERRAIN_MAX_CELLS=4000000
ExecStart=$VENV_ROOT/bin/gunicorn --workers 1 --threads 2 --timeout 300 --bind 0.0.0.0:8081 touchterrain.server.TouchTerrain_app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[7/8] Configurando o Nginx para o museu na porta 8080..."
sudo tee /etc/nginx/sites-available/geomaker >/dev/null <<EOF
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;
    root $SITE_ROOT;
    index index.html;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~* \.(?:css|js|jpg|jpeg|png|gif|svg|webp|ico|json|glb|stl|obj)$ {
        expires 7d;
        add_header Cache-Control "public, max-age=604800";
        try_files \$uri =404;
    }

    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
}
EOF
sudo ln -sfn /etc/nginx/sites-available/geomaker /etc/nginx/sites-enabled/geomaker
sudo nginx -t

echo "[8/8] Iniciando os serviços..."
if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl daemon-reload
  sudo systemctl enable --now nginx geomaker-touchterrain
else
  echo "O systemd não está ativo neste WSL; usando o modo compatível."
  sudo service nginx restart
  bash "$INSTALLER_ROOT/start.sh"
fi

echo
echo "Instalação concluída."
echo "Site:         http://localhost:8080"
echo "Laboratório:  http://localhost:8080/laboratorio.html"
echo "TouchTerrain: http://localhost:8081"
echo
echo "Próximo passo obrigatório para usar DEMs online:"
echo "  bash $INSTALLER_ROOT/autenticar-earthengine.sh"
echo
echo "Comandos úteis:"
echo "  bash $INSTALLER_ROOT/status.sh"
echo "  bash $INSTALLER_ROOT/start.sh"
echo "  bash $INSTALLER_ROOT/stop.sh"
echo "  bash $INSTALLER_ROOT/receber-site.sh /mnt/c/caminho/novo-site.zip"
