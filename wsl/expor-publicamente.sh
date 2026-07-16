#!/usr/bin/env bash
# expor-publicamente.sh — Expõe o Museu Geomaker na internet via Cloudflare Tunnel
#
# Modos de uso:
#   bash expor-publicamente.sh install          Instala cloudflared (se ausente)
#   bash expor-publicamente.sh tunnel DOMINIO   Cria túnel permanente para DOMINIO (ex: geomaker.org)
#   bash expor-publicamente.sh quick-tunnel     Túnel temporário *.trycloudflare.com (sem domínio)
#   bash expor-publicamente.sh status           Status do túnel
#   bash expor-publicamente.sh stop             Encerra o túnel
#   bash expor-publicamente.sh help             Esta mensagem
#
# Pré-requisitos:
#   - Site instalado em /opt/geomaker (bash wsl/setup.sh)
#   - Para túnel permanente: token Cloudflare em ~/.cloudflare/token

set -Eeu     # NOT pipefail — allow graceful handling of optional paths

APP_ROOT="/opt/geomaker"
TUNNEL_NAME="geomaker"
TUNNEL_DATA="$APP_ROOT/data/tunnel"
CFD_BIN="/usr/local/bin/cloudflared"
CFD_CONFIG_DIR="$HOME/.cloudflare"
CFD_TOKEN_FILE="$CFD_CONFIG_DIR/token"
PID_FILE="$TUNNEL_DATA/cloudflared.pid"
SERVICE_FILE="/etc/systemd/system/geomaker-tunnel.service"

mkdir -p "$TUNNEL_DATA" 2>/dev/null || true

on_error() {
  echo "Falha na linha $1. Consulte as mensagens acima."
}
trap 'on_error $LINENO' ERR

install_cloudflared() {
  if command -v cloudflared &>/dev/null; then
    echo "cloudflared já está instalado: $(cloudflared --version)"
    return
  fi
  echo "Instalando cloudflared..."
  local url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
  local deb="/tmp/cloudflared.deb"
  curl -sSL "$url" -o "$deb"
  sudo dpkg -i "$deb"
  rm -f "$deb"
  echo "cloudflared instalado: $(cloudflared --version)"
}

ensure_token() {
  if [[ ! -f "$CFD_TOKEN_FILE" ]]; then
    echo "Token do Cloudflare não encontrado em $CFD_TOKEN_FILE"
    echo
    echo "1. Acesse https://dash.cloudflare.com/profile/api-tokens"
    echo "2. Crie um token com permissão 'Cloudflare Tunnel — Edit'"
    echo "3. Salve o token em: $CFD_TOKEN_FILE"
    echo
    echo "Ou use 'quick-tunnel' para um túnel temporário sem token:"
    echo "  bash expor-publicamente.sh quick-tunnel"
    exit 1
  fi
  chmod 600 "$CFD_TOKEN_FILE"
}

cmd_install() {
  install_cloudflared
  echo
  echo "Pronto. Agora configure seu token:"
  echo "  bash expor-publicamente.sh tunnel geomaker.org"
  echo "Ou teste sem domínio:"
  echo "  bash expor-publicamente.sh quick-tunnel"
}

cmd_tunnel() {
  local domain="${1:-}"
  if [[ -z "$domain" ]]; then
    echo "Uso: bash expor-publicamente.sh tunnel SEU_DOMINIO.org"
    exit 1
  fi
  install_cloudflared
  ensure_token
  echo "Autenticando cloudflared com o token salvo..."
  cloudflared tunnel login --token "$(cat "$CFD_TOKEN_FILE")" 2>/dev/null || \
    cloudflared tunnel login
  echo "Criando túnel '$TUNNEL_NAME'..."
  cloudflared tunnel create "$TUNNEL_NAME" 2>/dev/null || true
  local cert="$HOME/.cloudflared/${TUNNEL_NAME}.json"
  if [[ ! -f "$cert" ]]; then
    echo "Falha ao criar túnel. Verifique o token."
    exit 1
  fi
  echo "Configurando DNS: $domain → túnel..."
  cloudflared tunnel route dns "$TUNNEL_NAME" "$domain" 2>/dev/null || {
    echo "Aviso: não foi possível ro tear o DNS automaticamente."
    echo "No Cloudflare Dashboard, crie um registro CNAME:"
    echo "  $domain → $TUNNEL_NAME.cfargotunnel.com"
  }
  local config="$CFD_CONFIG_DIR/config.yml"
  cat > "$config" <<EOF
tunnel: $TUNNEL_NAME
credentials-file: $cert
ingress:
  - hostname: $domain
    service: http://localhost:8080
  - hostname: lab.$domain
    service: http://localhost:8081
  - service: http_status:404
EOF
  cmd_stop 2>/dev/null || true
  if [[ "$(cat /proc/1/comm 2>/dev/null || true)" == "systemd" ]]; then
    sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel — Geomaker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
ExecStart=$(which cloudflared) tunnel run --token "$(cat "$CFD_TOKEN_FILE")"
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now geomaker-tunnel
    echo "Túnel iniciado como serviço systemd."
  else
    nohup cloudflared tunnel run "$TUNNEL_NAME" >> "$TUNNEL_DATA/tunnel.log" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Túnel iniciado em background (PID $(cat "$PID_FILE"))."
  fi
  echo
  echo "Túnel configurado para $domain"
  echo "Site: https://$domain"
  echo "Laboratório: https://lab.$domain"
  echo "TouchTerrain (embutido no laboratório): https://lab.$domain"
}

cmd_quick_tunnel() {
  install_cloudflared
  cmd_stop 2>/dev/null || true
  local url
  url=$(cloudflared tunnel --url http://localhost:8080 2>&1 | grep -oP 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' | head -1)
  if [[ -z "$url" ]]; then
    echo "Iniciando túnel temporário (pressione Ctrl+C para parar)..."
    cloudflared tunnel --url http://localhost:8080
  else
    echo "Túnel temporário ativo!"
    echo "URL pública: $url"
  fi
}

cmd_status() {
  local active=false
  local url=""
  if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    active=true
    url=$(cat "$TUNNEL_DATA/url.txt" 2>/dev/null || echo "geomaker.org (túnel permanente)")
  fi
  if systemctl is-active geomaker-tunnel &>/dev/null 2>&1; then
    active=true
    url=$(grep -r 'hostname:' "$CFD_CONFIG_DIR/config.yml" 2>/dev/null | head -1 | awk '{print $2}' || echo "geomaker.org")
  fi
  if command -v cloudflared &>/dev/null && cloudflared tunnel info "$TUNNEL_NAME" &>/dev/null 2>&1; then
    active=true
  fi
  if [[ "$active" == "true" ]]; then
    echo "[OK]    Túnel público: ativo — ${url:-URL não detectada}"
  else
    echo "[INATIVO] Túnel público: inativo"
    echo "         Para ativar: bash expor-publicamente.sh quick-tunnel"
    echo "         Ou:          bash expor-publicamente.sh tunnel SEU_DOMINIO"
  fi
}

cmd_stop() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "Túnel encerrado (PID $pid)."
    fi
    rm -f "$PID_FILE"
  fi
  if systemctl is-active geomaker-tunnel &>/dev/null 2>&1; then
    sudo systemctl stop geomaker-tunnel 2>/dev/null || true
    echo "Serviço geomaker-tunnel encerrado."
  fi
  pkill -f "cloudflared tunnel" 2>/dev/null || true
}

cmd_help() {
  cat <<'HELP'
Uso: bash expor-publicamente.sh <comando> [argumentos]

Comandos:
  install              Instala cloudflared (se ausente)
  tunnel DOMINIO       Cria túnel permanente para DOMINIO (ex: geomaker.org)
  quick-tunnel         Túnel temporário *.trycloudflare.com (sem domínio)
  status               Status do túnel público
  stop                 Encerra o túnel
  help                 Esta mensagem

Pré-requisitos:
  - Site instalado em /opt/geomaker (bash wsl/setup.sh)
  - Para túnel permanente: token Cloudflare em ~/.cloudflare/token

Exemplos:
  bash expor-publicamente.sh install
  bash expor-publicamente.sh tunnel geomaker.org
  bash expor-publicamente.sh quick-tunnel
  bash expor-publicamente.sh status
HELP
}

case "${1:-help}" in
  install)       cmd_install ;;
  tunnel)        cmd_tunnel "${2:-}" ;;
  quick-tunnel)  cmd_quick_tunnel ;;
  status)        cmd_status ;;
  stop)          cmd_stop ;;
  help|--help|-h) cmd_help ;;
  *)
    echo "Comando desconhecido: $1"
    cmd_help
    exit 1
    ;;
esac
