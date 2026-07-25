#!/usr/bin/env bash
# bootstrap.sh — apps y ajustes post end-4 (README fase 7).
# Idempotente: re-ejecutarlo es seguro (--needed no reinstala nada).
set -euo pipefail
cd "$(dirname "$0")"

command -v yay >/dev/null || { echo "Falta yay — instalalo primero (README fase 3)."; exit 1; }

echo "==> [1/9] Paquetes oficiales (pkgs-pacman.txt)"
grep -v '^\s*#' pkgs-pacman.txt | grep -v '^\s*$' | sudo pacman -S --needed --noconfirm -

echo "==> [2/9] Paquetes AUR (pkgs-aur.txt) — los -bin pueden tardar"
grep -v '^\s*#' pkgs-aur.txt | grep -v '^\s*$' | yay -S --needed --noconfirm -

echo "==> [3/9] Proteger paquetes de end-4 de pacman -Syu (IgnoreGroup)"
grep -q '^IgnoreGroup *=.*illogical-impulse' /etc/pacman.conf ||
	sudo sed -i '/^\[options\]/a IgnoreGroup = illogical-impulse' /etc/pacman.conf

echo "==> [4/9] Virtualización: servicio libvirt + grupo de usuario"
sudo systemctl enable libvirtd.service
sudo usermod -aG libvirt "$USER"

echo "==> [5/9] npm global en el home (sin sudo, evita errores de permisos)"
mkdir -p ~/.local/share/npm-global
npm config set prefix ~/.local/share/npm-global

echo "==> [6/9] Claude Code (instalador oficial)"
command -v claude >/dev/null || [ -x ~/.local/bin/claude ] ||
	curl -fsSL https://claude.ai/install.sh | bash

echo "==> [7/9] Tema de fastfetch con imágenes (LierB)"
[ -d ~/.local/share/fastfetch ] ||
	git clone https://github.com/LierB/fastfetch ~/.local/share/fastfetch

echo "==> [8/9] Carpetas de imágenes"
mkdir -p ~/Pictures/{Wallpapers,Screenshots,FastfetchLogos}

echo "==> [9/9] Identidad de git (solo si no existe) y permisos de scripts"
git config --global user.name >/dev/null 2>&1 || git config --global user.name "Ander0296"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "165844215+Ander0296@users.noreply.github.com"
chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true

echo ""
echo "Bootstrap listo. El grupo libvirt aplica al próximo login."
echo "Siguen los pasos manuales del README (fase 9):"
echo "  1Password + SSH agent · remoto a SSH · claude login · gentle-ai · nvim · secrets.fish · wallpapers"
