#!/usr/bin/env bash
set -u

check_url() {
  local label="$1"
  local url="$2"
  local code
  code="$(curl -sS -o /dev/null --max-time 8 -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ "$code" == "200" ]]; then
    echo "[OK]    $label — $url"
  else
    echo "[FALHA] $label — HTTP ${code:-sem resposta}"
  fi
}

check_url "Site do museu" "http://localhost:8080/index.html"
check_url "Terra Antiga local" "http://localhost:8080/assets/ancient-earth/index.html#600"
check_url "TouchTerrain local" "http://localhost:8081/"
check_url "Ponte OpenCode (terminal)" "http://localhost:8082/health"

if command -v opencode >/dev/null 2>&1; then
  echo "[OK]    CLI OpenCode instalado ($(opencode --version 2>/dev/null || echo 'versão desconhecida'))"
else
  echo "[ATENÇÃO] CLI OpenCode não encontrado no PATH — rode: npm install -g opencode-ai"
fi

if [[ -f "$HOME/.local/share/opencode/auth.json" ]]; then
  echo "[OK]    OpenCode autenticado (auth.json encontrado)"
else
  echo "[ATENÇÃO] OpenCode ainda não autenticado — rode: opencode auth login"
fi

if systemctl is-active --quiet geomaker-touchterrain-watchdog.timer 2>/dev/null; then
  echo "[OK]    Watchdog do TouchTerrain ativo"
else
  echo "[ATENÇÃO] Watchdog do TouchTerrain inativo (systemd pode não estar disponível neste WSL)"
fi

if [[ -f "$HOME/.config/earthengine/credentials" ]]; then
  echo "[OK]    Credencial do Earth Engine encontrada"
else
  echo "[ATENÇÃO] Earth Engine ainda não autenticado"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/expor-publicamente.sh" status 2>/dev/null || echo "[INATIVO] Túnel público: inativo"
