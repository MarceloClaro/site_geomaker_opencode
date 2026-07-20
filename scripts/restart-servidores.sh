#!/usr/bin/env bash
# =============================================================================
# restart-servidores.sh — Reinicia todos os servidores do Geomaker
#                        Respeita a ordem de dependências (backends → nginx → túnel)
# Uso:
#   restart-servidores                    # Reinicia tudo (padrão)
#   restart-servidores status             # Mostra estado de todos os serviços
#   restart-servidores restart            # Reinicia tudo
#   restart-servidores stop               # Para tudo
#   restart-servidores start              # Inicia tudo
#   restart-servidores nginx              # Apenas nginx
#   restart-servidores api                # Apenas geomaker-api (porta 8082)
#   restart-servidores touchterrain       # Apenas geomaker-touchterrain (porta 8081)
#   restart-servidores tunnel             # Apenas túneis Cloudflare
#   restart-servidores log [n]            # Mostra logs recentes (padrão: 30 linhas)
# =============================================================================

# NÃO use set -e (pipefail com grep em condicionais quebra).
# Erros são tratados explicitamente nas funções.

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Configurações ────────────────────────────────────────────────────────────
SERVICES=(
  "nginx"
  "geomaker-api"
  "geomaker-touchterrain"
)

# Túneis Cloudflare (processos de usuário, sem systemd)
CLOUDFLARE_TUNNELS=(
  "http://localhost:8080"
  "http://localhost:8081"
  "http://localhost:8084"
)
CLOUDFLARE_BIN="cloudflared"

# ─── Cores / helpers ──────────────────────────────────────────────────────────
info()  { echo -e "${CYAN}$1${NC}"; }
ok()    { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()   { echo -e "${RED}❌ $1${NC}"; }
header(){ echo -e "\n${BOLD}━━━ $1 ━━━${NC}"; }

# ─── Funções de serviço ───────────────────────────────────────────────────────
svc_restart() {
  local name="$1"
  info "↻ Reiniciando ${name}..."
  if sudo systemctl restart "$name" 2>/dev/null; then
    ok "${name} reiniciado"
  else
    err "${name} falhou ao reiniciar"
    return 1
  fi
}

svc_stop() {
  local name="$1"
  info "⏹ Parando ${name}..."
  sudo systemctl stop "$name" 2>/dev/null || warn "${name} ja estava parado"
}

svc_start() {
  local name="$1"
  info "▶ Iniciando ${name}..."
  if sudo systemctl start "$name" 2>/dev/null; then
    ok "${name} iniciado"
  else
    err "${name} falhou ao iniciar"
    return 1
  fi
}

svc_status() {
  local name="$1"
  local active="$(systemctl is-active "$name" 2>/dev/null || echo "desconhecido")"
  local enabled="$(systemctl is-enabled "$name" 2>/dev/null || echo "desconhecido")"
  if [ "$active" = "active" ]; then
    echo -e "  ${GREEN}●${NC} ${name}: ${GREEN}${active}${NC} (enabled: ${enabled})"
  else
    echo -e "  ${RED}○${NC} ${name}: ${RED}${active}${NC} (enabled: ${enabled})"
  fi
}

# ─── Túneis Cloudflare ────────────────────────────────────────────────────────
tunnel_pids() {
  # Apenas processos cloudflared que contêm "--url" (filtra pai sem filhos específicos e self-grep)
  ps -eo pid,args --no-headers 2>/dev/null \
    | awk '/cloudflared/ && /--url/ && !/awk/ && !/grep/ && !/nohup/ {print $1}' \
    | tr '\n' ' '
}

tunnel_stop() {
  local pids
  pids="$(tunnel_pids | xargs)"
  if [ -n "${pids// /}" ]; then
    info "⏹ Parando túneis Cloudflare (PIDs: $pids)..."
    kill $pids 2>/dev/null || true
    local waited=0
    while [ "$waited" -lt 8 ]; do
      sleep 1
      pids="$(tunnel_pids | xargs)"
      [ -z "${pids// /}" ] && break
      ((waited++))
    done
    pids="$(tunnel_pids | xargs)"
    if [ -n "${pids// /}" ]; then
      warn "Forçando kill -9 em $pids..."
      kill -9 $pids 2>/dev/null || true
      sleep 1
    fi
    ok "Túneis Cloudflare parados"
  else
    warn "Nenhum túnel Cloudflare rodando"
  fi
}

tunnel_start() {
  info "▶ Iniciando túneis Cloudflare..."
  local started=0
  for url in "${CLOUDFLARE_TUNNELS[@]}"; do
    # Verificar se já existe (ps+awk extrai o PID, grep -v exclui o proprio processo)
    local running="$(ps -eo pid,args --no-headers 2>/dev/null | awk '/cloudflared.*tunnel.*--url.*'"${url//\//\\/}"'/ && !/awk/ && !/grep/ && !/nohup/ {print $1}')"
    if [ -n "$running" ]; then
      warn "Túnel para ${url} já existe (PID $running)"
    else
      nohup "$CLOUDFLARE_BIN" tunnel --url "$url" > /dev/null 2>&1 &
      ((started++))
      sleep 2
    fi
  done
  if [ "$started" -gt 0 ]; then
    ok "${started} túnel(is) iniciado(s)"
  fi
}

tunnel_status() {
  local pids
  pids="$(tunnel_pids | xargs)"  # normaliza whitespace
  if [ -n "${pids// /}" ]; then
    echo -e "  ${GREEN}●${NC} cloudflared (PIDs: $pids)"
    # Mostrar cada túnel — ps com pids como numeros
    for pid in $pids; do
      [ -z "$pid" ] && continue
      local cmdline
      cmdline="$(ps -p "$pid" -o args= 2>/dev/null)" || continue
      local url="$(echo "$cmdline" | sed -n 's/.*--url //p')"
      echo -e "    └─ PID ${pid} → ${url}"
    done
  else
    echo -e "  ${RED}○${NC} cloudflared: ${RED}parado${NC}"
  fi
}

# ─── Port check helper ────────────────────────────────────────────────────────
check_port() {
  local port="$1"
  local expected="$2"
  if ss -tlnp 2>/dev/null | grep -q ":$port "; then
    echo -e "    ${GREEN}●${NC} porta ${port} — ${expected}"
  else
    echo -e "    ${RED}○${NC} porta ${port} — ${RED}NÃO ESCUTANDO${NC} (esperado: ${expected})"
  fi
}

# ─── Ações ────────────────────────────────────────────────────────────────────
do_status() {
  header "STATUS DOS SERVIÇOS"
  for svc in "${SERVICES[@]}"; do
    svc_status "$svc"
  done
  echo ""
  tunnel_status

  header "PORTAS"
  check_port 80 "Nginx (HTTP)"
  check_port 8080 "Nginx (Geomaker site)"
  check_port 8084 "Nginx (porta extra)"
  check_port 8081 "TouchTerrain (Gunicorn)"
  check_port 8082 "API (FastAPI)"

  header "RESUMO"
  local total=${#SERVICES[@]}
  local ativos=0
  for svc in "${SERVICES[@]}"; do
    if [ "$(systemctl is-active "$svc" 2>/dev/null)" = "active" ]; then
      ((ativos++))
    fi
  done
  if [ -n "$(tunnel_pids)" ]; then
    ((ativos++))
  fi
  echo -e "  ${ativos}/${total} serviços systemd ativos + túneis"
}

do_stop() {
  header "PARANDO SERVIDORES (ordem reversa)"
  tunnel_stop
  for svc in "${SERVICES[@]}"; do
    svc_stop "$svc"
  done
  ok "Servidores parados"
}

do_start() {
  header "INICIANDO SERVIDORES (ordem de dependências)"
  for svc in "${SERVICES[@]}"; do
    svc_start "$svc"
  done
  tunnel_start
  ok "Servidores iniciados"

  # Pequena pausa para os serviços estabilizarem
  sleep 2
  do_status
}

do_restart() {
  header "REINICIANDO TODOS OS SERVIDORES"
  echo -e "${YELLOW}Ordem: para túneis → backends → nginx, sobe nginx → backends → túneis${NC}"

  # — FASE 1: PARAR (ordem reversa) —
  tunnel_stop
  # Parar nginx primeiro (para não ficar com proxy quebrado)
  svc_stop "nginx"
  # Depois backends
  svc_stop "geomaker-api"
  svc_stop "geomaker-touchterrain"

  # Pequena pausa para garantir liberação de portas
  sleep 1

  # — FASE 2: INICIAR (ordem de dependências) —
  svc_start "geomaker-api"
  svc_start "geomaker-touchterrain"
  sleep 2
  svc_start "nginx"
  tunnel_start

  ok "Servidores reiniciados"

  # — FASE 3: VERIFICAÇÃO —
  sleep 2
  do_status
}

do_log() {
  local lines="${1:-30}"
  header "LOGS RECENTES"
  for svc in "${SERVICES[@]}"; do
    echo -e "\n${BOLD}${svc}:${NC}"
    sudo journalctl -u "$svc" --no-pager -n "$lines" 2>/dev/null || warn "(sem logs)"
  done
  echo -e "\n${BOLD}nginx (access log):${NC}"
  tail -"$lines" /var/log/nginx/access.log 2>/dev/null || warn "(sem log)"
  echo -e "\n${BOLD}nginx (error log):${NC}"
  tail -"$lines" /var/log/nginx/error.log 2>/dev/null || warn "(sem log)"
  echo -e "\n${BOLD}API log:${NC}"
  tail -"$lines" /var/log/geomaker-api.log 2>/dev/null || warn "(sem log)"
}

# ─── Comandos de serviço individual ───────────────────────────────────────────
do_service() {
  local action="$1"
  local service="$2"
  case "$action" in
    restart) svc_restart "$service" ;;
    stop)    svc_stop "$service" ;;
    start)   svc_start "$service" ;;
    status)  svc_status "$service" ;;
  esac
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  # Verificar permissão sudo
  if ! sudo -n true 2>/dev/null; then
    warn "Este script requer sudo (alguns comandos podem pedir senha)"
  fi

  local cmd="${1:-restart}"
  shift 2>/dev/null || true

  # ─── Comandos de serviço individual ──
  case "$cmd" in
    nginx|api|touchterrain)
      local svc_name=""
      case "$cmd" in
        nginx)         svc_name="nginx" ;;
        api)           svc_name="geomaker-api" ;;
        touchterrain)  svc_name="geomaker-touchterrain" ;;
      esac
      do_service "${1:-restart}" "$svc_name"
      ;;
    tunnel)
      case "${1:-status}" in
        start)   tunnel_start ;;
        stop)    tunnel_stop ;;
        restart) tunnel_stop; tunnel_start ;;
        status)  tunnel_status ;;
        *)       echo "Uso: $0 tunnel {start|stop|restart|status}" ;;
      esac
      ;;
    status)  do_status ;;
    log)     do_log "${1:-30}" ;;
    stop)    do_stop ;;
    start)   do_start ;;
    restart) do_restart ;;
    *)
      echo -e "${BOLD}Uso:${NC} $0 {comando} [opções]"
      echo ""
      echo "Comandos:"
      echo "  restart          Reinicia todos os servidores (padrão)"
      echo "  start            Inicia todos os servidores"
      echo "  stop             Para todos os servidores"
      echo "  status           Mostra estado de todos os serviços"
      echo "  log [n]          Mostra últimas n linhas dos logs (padrão: 30)"
      echo ""
      echo "Serviço individual:"
      echo "  nginx [ação]     Apenas nginx (ação: start|stop|restart)"
      echo "  api [ação]       Apenas geomaker-api (porta 8082)"
      echo "  touchterrain [a] Apenas geomaker-touchterrain (porta 8081)"
      echo "  tunnel [ação]    Apenas túneis Cloudflare"
      echo ""
      echo "Exemplos:"
      echo "  $0               # Reinicia tudo"
      echo "  $0 status        # Mostra status"
      echo "  $0 api restart   # Reinicia só a API"
      echo "  $0 tunnel stop   # Para túneis Cloudflare"
      echo "  $0 log 50        # Últimas 50 linhas dos logs"
      ;;
  esac
}

main "$@"
