#!/usr/bin/env bash
# Instala Museu Geomaker + Ancient Earth + TouchTerrain + ponte OpenCode
# (terminal, dissertações ABNT, watchdog) localmente no WSL Ubuntu.
#
# Uso normal (já com o repositório clonado/extraído):
#   bash wsl/setup.sh
#
# Para instalar do zero com um único comando, use instalar.sh na raiz do
# repositório (ele baixa este pacote e chama este script automaticamente).
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_ROOT="/opt/geomaker"
SITE_ROOT="$APP_ROOT/site"
TOUCH_ROOT="$APP_ROOT/touchterrain"
VENV_ROOT="$APP_ROOT/venv"
BRIDGE_ROOT="$APP_ROOT/opencode-bridge"
BRIDGE_VENV="$APP_ROOT/opencode-bridge-venv"
DATA_ROOT="$APP_ROOT/data"
INSTALLER_ROOT="$APP_ROOT/installer"
CURRENT_USER="${USER}"
CURRENT_GROUP="$(id -gn)"
CURRENT_HOME="${HOME}"
TOUCHTERRAIN_FORK_URL="https://github.com/MarceloClaro/TouchTerrain_for_CAGEO.git"

on_error() {
  echo
  echo "Falha na linha $1. Consulte as mensagens acima e execute novamente: bash wsl/setup.sh"
  echo "Se o erro persistir, copie a mensagem acima e peça ajuda — inclua o passo que falhou."
}
trap 'on_error $LINENO' ERR

if [[ "$EUID" -eq 0 ]]; then
  echo "Execute como usuário normal, sem colocar sudo antes do script. O instalador pedirá sudo quando necessário."
  exit 1
fi

if ! grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
  echo "Aviso: o ambiente não parece ser WSL. A instalação continuará como Ubuntu/Debian comum."
fi

if [[ ! -f "$PACKAGE_ROOT/index.html" ]]; then
  echo "Pacote incompleto. Extraia/clone o repositório inteiro e execute este arquivo dentro da pasta."
  exit 1
fi

TOTAL_PASSOS=12
PASSO=0
passo() {
  PASSO=$((PASSO + 1))
  echo
  echo "[$PASSO/$TOTAL_PASSOS] $1"
}

passo "Atualizando pacotes do Ubuntu..."
sudo -v
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  nginx unzip rsync curl ca-certificates gnupg build-essential git \
  python3 python3-venv python3-pip python3-dev \
  gdal-bin libgdal-dev python3-gdal python3-numpy python3-scipy python3-pil \
  poppler-utils texlive-latex-extra texlive-fonts-recommended lmodern

passo "Instalando Node.js 22.x (necessário para o CLI OpenCode)..."
if ! command -v node >/dev/null 2>&1 || [[ "$(node --version | grep -oE '^v[0-9]+' | tr -d v)" -lt 20 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
  sudo apt-get install -y nodejs
else
  echo "Node.js já instalado: $(node --version)"
fi

passo "Baixando o fork do TouchTerrain (dados de terreno 3D)..."
VENDOR_DIR="$SCRIPT_DIR/vendor/TouchTerrain_for_CAGEO"
if [[ ! -d "$VENDOR_DIR" ]]; then
  mkdir -p "$SCRIPT_DIR/vendor"
  git clone --depth 1 "$TOUCHTERRAIN_FORK_URL" "$VENDOR_DIR"
else
  echo "Fork já presente em $VENDOR_DIR (pulei o download)."
fi

passo "Criando a instalação em $APP_ROOT..."
sudo install -d -o "$CURRENT_USER" -g "$CURRENT_GROUP" \
  "$APP_ROOT" "$SITE_ROOT" "$TOUCH_ROOT" "$VENV_ROOT" \
  "$BRIDGE_ROOT" "$BRIDGE_VENV" \
  "$DATA_ROOT" "$DATA_ROOT/tmp" "$DATA_ROOT/downloads" "$DATA_ROOT/previews" \
  "$DATA_ROOT/exports" "$DATA_ROOT/logs" "$DATA_ROOT/projetos" "$INSTALLER_ROOT"

passo "Instalando os arquivos do site, da Terra Antiga e da ponte OpenCode..."
rsync -a --exclude='wsl' --exclude='node_modules' --exclude='opencode-bridge' --exclude='deploy' \
  "$PACKAGE_ROOT/" "$SITE_ROOT/"
rsync -a "$VENDOR_DIR/" "$TOUCH_ROOT/"
rsync -a --exclude='vendor' "$SCRIPT_DIR/" "$INSTALLER_ROOT/"
rsync -a "$PACKAGE_ROOT/opencode-bridge/" "$BRIDGE_ROOT/"
rsync -a "$PACKAGE_ROOT/deploy/scripts/" "$INSTALLER_ROOT/"
chmod +x "$INSTALLER_ROOT"/*.sh 2>/dev/null || true
ln -sfn "$DATA_ROOT/projetos" "$SITE_ROOT/projeto"

passo "Criando o ambiente Python do TouchTerrain..."
if [[ ! -x "$VENV_ROOT/bin/python" ]]; then
  python3 -m venv --system-site-packages "$VENV_ROOT"
fi
"$VENV_ROOT/bin/python" -m pip install --upgrade pip wheel setuptools
"$VENV_ROOT/bin/python" -m pip install -r "$INSTALLER_ROOT/requirements-wsl.txt"

echo "Validando Python, GDAL e o código empacotado..."
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

passo "Instalando o CLI OpenCode (terminal do Geólogo Digital)..."
export NPM_CONFIG_PREFIX="$CURRENT_HOME/.npm-global"
mkdir -p "$NPM_CONFIG_PREFIX"
if ! grep -q '.npm-global/bin' "$CURRENT_HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$CURRENT_HOME/.bashrc"
fi
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"
npm install -g opencode-ai
OPENCODE_BIN="$NPM_CONFIG_PREFIX/bin/opencode"

passo "Criando o ambiente Python da ponte OpenCode (FastAPI)..."
if [[ ! -x "$BRIDGE_VENV/bin/python" ]]; then
  python3 -m venv "$BRIDGE_VENV"
fi
"$BRIDGE_VENV/bin/python" -m pip install --upgrade pip wheel
"$BRIDGE_VENV/bin/python" -m pip install fastapi "uvicorn[standard]" pydantic

passo "Configurando os serviços systemd (TouchTerrain, ponte OpenCode, watchdog)..."
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
Environment=HOME=$CURRENT_HOME
Environment=PYTHONPATH=$TOUCH_ROOT
Environment=TOUCHTERRAIN_TMP_FOLDER=$DATA_ROOT/tmp
Environment=TOUCHTERRAIN_DOWNLOADS_FOLDER=$DATA_ROOT/downloads
Environment=TOUCHTERRAIN_PREVIEWS_FOLDER=$DATA_ROOT/previews
Environment=TOUCHTERRAIN_GOOGLE_MAPS_KEY_FILE=$DATA_ROOT/GoogleMapsKey.txt
Environment=TOUCHTERRAIN_GA_ID=
Environment=TOUCHTERRAIN_MAX_CELLS=4000000
ExecStart=$VENV_ROOT/bin/gunicorn --workers 2 --threads 4 --timeout 600 --bind 0.0.0.0:8081 touchterrain.server.TouchTerrain_app:app
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/geomaker-opencode-bridge.service >/dev/null <<EOF
[Unit]
Description=OpenCode Bridge — Geomaker (FastAPI)
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$BRIDGE_ROOT
Environment="PORT=8082"
Environment="HOST=127.0.0.1"
Environment="OPENCODE_BIN=$OPENCODE_BIN"
Environment="OPENCODE_MODEL=opencode/deepseek-v4-flash-free"
Environment="OPENCODE_AGENT=marceloclaro"
Environment="OPENCODE_WORK_DIR=$BRIDGE_ROOT"
ExecStart=$BRIDGE_VENV/bin/python -m uvicorn server:app --host 127.0.0.1 --port 8082
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/geomaker-touchterrain-watchdog.service >/dev/null <<EOF
[Unit]
Description=TouchTerrain Watchdog — verifica /main e reinicia geomaker-touchterrain se travado
After=geomaker-touchterrain.service

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 $INSTALLER_ROOT/touchterrain_watchdog.py --url http://localhost:8081/main --service geomaker-touchterrain --timeout 10
User=root
EOF

sudo tee /etc/systemd/system/geomaker-touchterrain-watchdog.timer >/dev/null <<'EOF'
[Unit]
Description=Timer para TouchTerrain Watchdog (a cada 2 minutos)

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF

passo "Configurando o Nginx para o museu na porta 8080 (site + ponte OpenCode + TouchTerrain)..."
sudo tee /etc/nginx/sites-available/geomaker >/dev/null <<EOF
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;
    charset utf-8;

    location ^~ /main {
        proxy_pass http://localhost:8081/main;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600;
    }

    location ^~ /export {
        proxy_pass http://localhost:8081/export;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600;
        client_max_body_size 100M;
    }

    location ^~ /preview/ {
        proxy_pass http://localhost:8081/preview/;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600;
    }

    location ^~ /download/ {
        proxy_pass http://localhost:8081/download/;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600;
    }

    location ^~ /static/ {
        proxy_pass http://localhost:8081/static/;
        proxy_set_header Host \$http_host;
        proxy_read_timeout 600;
    }

    location ^~ /touchterrain/ {
        proxy_pass http://localhost:8081/;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600;
    }

    location ^~ /api/ {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600;
        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;
    }

    root $SITE_ROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~* \.(?:css|js|jpg|jpeg|png|gif|svg|webp|ico|json|glb|stl|obj)\$ {
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

passo "Iniciando todos os serviços..."
if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
  sudo systemctl daemon-reload
  sudo systemctl enable --now nginx geomaker-touchterrain geomaker-opencode-bridge geomaker-touchterrain-watchdog.timer
else
  echo "O systemd não está ativo neste WSL; usando o modo compatível."
  sudo service nginx restart
  bash "$INSTALLER_ROOT/start.sh"
fi

passo "Instalação concluída!"
echo
echo "═══════════════════════════════════════════════════════════════"
echo "  MUSEU GEOMAKER — pronto em http://localhost:8080"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "  Site:              http://localhost:8080"
echo "  Acervo (terminal):  http://localhost:8080/acervo.html"
echo "  Laboratório:        http://localhost:8080/laboratorio.html"
echo "  TouchTerrain:       http://localhost:8080/main"
echo
echo "PRÓXIMOS PASSOS (opcionais, um de cada vez):"
echo
echo "  1) Ativar o terminal do Geólogo Digital (converse com IA no site):"
echo "       opencode auth login"
echo "     (siga o link que aparecer no navegador e faça login uma vez)"
echo
echo "  2) Ativar dados de terreno online no gerador 3D (Earth Engine):"
echo "       bash $INSTALLER_ROOT/autenticar-earthengine.sh"
echo "     (sem esse passo, o gerador ainda funciona com arquivos locais)"
echo
echo "Comandos úteis:"
echo "  bash $INSTALLER_ROOT/status.sh     — ver se tudo está rodando"
echo "  bash $INSTALLER_ROOT/start.sh      — iniciar os serviços"
echo "  bash $INSTALLER_ROOT/stop.sh       — parar os serviços"
echo "  bash $INSTALLER_ROOT/receber-site.sh /mnt/c/caminho/novo-site.zip"
echo
