#!/usr/bin/env bash
# ============================================================================
# restart-all.sh
# Reinicia todos os servidores do Geomaker + túnel Cloudflare.
# Pode ser chamado do Linux direto ou do Windows via wsl.
# ============================================================================
set -euo pipefail

VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
RESET='\033[0m'

log()  { echo -e "${VERDE}[$(date '+%H:%M:%S')]${RESET} $1"; }
warn() { echo -e "${AMARELO}[AVISO]${RESET} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TUNNEL_LOG="$SCRIPT_DIR/tunnel.log"
SERVER_LOG="$SCRIPT_DIR/relevo-server.log"

# ============================================================================
# 1. MATAR PROCESSOS ANTIGOS
# ============================================================================
log "🛑 Parando processos antigos..."

# Node server (relevo-server.cjs)
NODE_PID=$(ps aux | grep "relevo-server" | grep -v grep | awk '{print $2}' || true)
if [ -n "$NODE_PID" ]; then
    kill "$NODE_PID" 2>/dev/null && log "   Node server (PID $NODE_PID) parado" || warn "   Falha ao parar Node server"
else
    log "   Nenhum Node server rodando"
fi

# Cloudflared tunnel
CF_PIDS=$(ps aux | grep cloudflared | grep -v grep | awk '{print $2}' || true)
if [ -n "$CF_PIDS" ]; then
    for pid in $CF_PIDS; do
        kill "$pid" 2>/dev/null && log "   Cloudflared (PID $pid) parado" || true
    done
else
    log "   Nenhum cloudflared rodando"
fi

sleep 2

# ============================================================================
# 2. INICIAR NODE SERVER (porta 8083)
# ============================================================================
log "🚀 Iniciando Node server (porta 8083)..."
nohup node /opt/geomaker/site/relevo-server.cjs > "$SERVER_LOG" 2>&1 &
NODE_PID=$!
sleep 2

# Verificar se subiu
if curl -s --max-time 3 http://127.0.0.1:8083/api/relevo/status > /dev/null 2>&1; then
    log "   ✅ Node server OK (PID $NODE_PID) — http://localhost:8083"
else
    warn "   ❌ Node server falhou. Log: $SERVER_LOG"
    tail -5 "$SERVER_LOG"
fi

# ============================================================================
# 3. INICIAR TÚNEL CLOUDFLARED
# ============================================================================
log "🚀 Iniciando túnel Cloudflare..."

# Limpa log ANTES de iniciar para não pegar URL de sessão antiga
: > "$TUNNEL_LOG"

nohup cloudflared tunnel --url http://localhost:8080 > "$TUNNEL_LOG" 2>&1 &
CF_PID=$!

# Aguardar URL do túnel (lê do FINAL do arquivo, não do início)
TUNNEL_URL=""
for i in $(seq 1 20); do
    # Pega APENAS a última URL que apareceu no log (a mais recente)
    TUNNEL_URL=$(grep -oP 'https://[a-z-]+\.trycloudflare\.com' "$TUNNEL_LOG" 2>/dev/null | tail -1)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    sleep 1
done

if [ -n "${TUNNEL_URL:-}" ]; then
    log "   ✅ Túnel ativo (PID $CF_PID)"
    log "   🔗 URL pública: ${AZUL}${TUNNEL_URL}${RESET}"

    # ── Atualizar/criar atalhos no Desktop do Windows ──
    SHORTCUT_TUNEL="/mnt/c/Users/marce/Desktop/Abrir Geomaker (Tunel).url"
    SHORTCUT_LOCAL="/mnt/c/Users/marce/Desktop/Abrir Geomaker (Local).url"
    SHORTCUT_PADRAO="/mnt/c/Users/marce/Desktop/Abrir Geomaker.url"

    # Tunel + padrão: sempre criar/atualizar com a URL pública
    for s in "$SHORTCUT_TUNEL" "$SHORTCUT_PADRAO"; do
        mkdir -p "$(dirname "$s")"
        printf '[InternetShortcut]\nURL=%s\nIconIndex=0\nIconFile=C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe\n' \
            "$TUNNEL_URL" > "$s"
        log "   🖥️  Atalho criado/atualizado: $(basename "$s") → $TUNNEL_URL"
    done

    # Local: sempre criar/atualizar com localhost
    mkdir -p "$(dirname "$SHORTCUT_LOCAL")"
    printf '[InternetShortcut]\nURL=http://localhost:8080\nIconIndex=0\nIconFile=C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe\n' \
        > "$SHORTCUT_LOCAL"
    log "   🖥️  Atalho criado/atualizado: $(basename "$SHORTCUT_LOCAL") → http://localhost:8080"
else
    warn "   ⏳ Túnel ainda iniciando... URL em: cat $TUNNEL_LOG"
    TUNNEL_URL="(ainda iniciando)"
fi

# ============================================================================
# 4. RESUMO
# ============================================================================
echo ""
log "══════════════════════════════════════════════════════"
log "  ✅ GEOMAKER — TUDO NO AR"
log "══════════════════════════════════════════════════════"
echo ""
log "   📍 Local:     http://localhost:8080"
log "   📍 API:       http://localhost:8083"
log "   📍 Modelos:   http://localhost:8080/saidas/"
log "   📍 Gerador:   http://localhost:8080/relevo-papel.html"
echo ""
log "   🌍 Público:   $TUNNEL_URL"
echo ""
log "   ⚙️  Scripts:   $SCRIPT_DIR"
log "   📊 Logs:      $SERVER_LOG"
log "                 $TUNNEL_LOG"
echo ""
log "   🛡️  Watchdog Node ativo (verifica a cada 30s)"
echo ""
log "══════════════════════════════════════════════════════"

# ============================================================================
# 5. INICIAR WATCHDOG (se não estiver rodando)
# ============================================================================
WATCHDOG_SCRIPT="$SCRIPT_DIR/watchdog-node.sh"
if ! pgrep -f "watchdog-node.sh" > /dev/null 2>&1; then
    nohup bash "$WATCHDOG_SCRIPT" > /dev/null 2>&1 &
    log "   🛡️  Watchdog Node iniciado (PID $!)"
else
    log "   🛡️  Watchdog Node já está rodando"
fi
