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

if [[ -f "$HOME/.config/earthengine/credentials" ]]; then
  echo "[OK]    Credencial do Earth Engine encontrada"
else
  echo "[ATENÇÃO] Earth Engine ainda não autenticado"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/expor-publicamente.sh" status 2>/dev/null || echo "[INATIVO] Túnel público: inativo"
