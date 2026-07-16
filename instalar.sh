#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════
#  MUSEU GEOMAKER — instalador de um único comando (do zero até rodando)
# ═══════════════════════════════════════════════════════════════════════
#
# Este script é o ÚNICO comando necessário para instalar o Museu Geomaker
# num WSL Ubuntu recém-instalado (ou Ubuntu/Debian comum). Ele baixa o
# projeto, instala todas as dependências e deixa o site rodando em
# http://localhost:8080.
#
# Uso (dentro do terminal Ubuntu/WSL):
#
#   curl -fsSL https://raw.githubusercontent.com/marceloclaro/site_geomaker_opencode/main/instalar.sh | bash
#
# Ou, se já baixou o repositório manualmente:
#
#   bash instalar.sh
#
# Pode ser executado várias vezes sem problema (é seguro repetir).
set -Eeuo pipefail

REPO_URL="https://github.com/marceloclaro/site_geomaker_opencode.git"
DEST_DIR="${GEOMAKER_INSTALL_DIR:-$HOME/Geomaker_site}"

echo "═══════════════════════════════════════════════════════════════"
echo "  MUSEU GEOMAKER — instalação automática"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "Isso vai instalar o site do museu, o gerador de terrenos 3D e o"
echo "terminal do Geólogo Digital (IA) no seu WSL. Leva de 5 a 15"
echo "minutos, dependendo da internet. Pode deixar essa janela aberta"
echo "e esperar — ela vai avisar quando terminar."
echo

if [[ "$EUID" -eq 0 ]]; then
  echo "Não execute como root/sudo. Rode como seu usuário normal do Ubuntu;"
  echo "o instalador vai pedir a senha (sudo) somente quando precisar."
  exit 1
fi

echo "[passo 1 de 3] Preparando o download do projeto..."
sudo -v
if ! command -v git >/dev/null 2>&1; then
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y git
fi

echo "[passo 2 de 3] Baixando (ou atualizando) o Museu Geomaker em $DEST_DIR ..."
if [[ -d "$DEST_DIR/.git" ]]; then
  git -C "$DEST_DIR" pull --ff-only
else
  git clone --depth 1 "$REPO_URL" "$DEST_DIR"
fi

echo "[passo 3 de 3] Instalando tudo (site, TouchTerrain, terminal com IA)..."
cd "$DEST_DIR"
chmod +x wsl/*.sh
bash wsl/setup.sh

echo
echo "Tudo pronto! O instalador principal (wsl/setup.sh) já mostrou os"
echo "endereços do site e os próximos passos opcionais acima."
