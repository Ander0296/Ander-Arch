#!/usr/bin/env bash
# bootstrap.sh — apps y ajustes post end-4 (README fase 7).
# Idempotente: re-ejecutarlo es seguro (--needed no reinstala nada).
set -euo pipefail
cd "$(dirname "$0")"

command -v yay >/dev/null || { echo "Falta yay — instalalo primero (README fase 3)."; exit 1; }

echo "==> [1/10] Habilitar repo multilib (necesario para Steam / Wallpaper Engine)"
grep -q '^\[multilib\]' /etc/pacman.conf ||
	sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

echo "==> [2/10] Actualizar el sistema (interactivo a propósito)"
# -Syu (no solo -Sy): actualiza TODO el sistema antes de instalar la lista,
# evitando "partial upgrades" que rompen libs compartidas (poppler vs poppler-qt6).
# SIN --noconfirm: cuando un paquete nuevo conflictúa con uno viejo (ej:
# qemu-common 11.1 vs qemu-block-gluster) pacman pregunta "Remove X? [y/N]".
# --noconfirm NO dice "sí a todo": responde el default, que ahí es N, y aborta
# con "unresolvable package conflicts". Contestando a mano el upgrade pasa.
sudo pacman -Syu

echo "==> [2b/10] Paquetes oficiales (pkgs-pacman.txt)"
# Venimos de un -Syu recién hecho: -S (sin -y) es seguro, no hay riesgo de
# partial upgrade, y --needed no reinstala lo que ya está.
grep -v '^\s*#' pkgs-pacman.txt | grep -v '^\s*$' | sudo pacman -S --needed --noconfirm -

echo "==> [3/10] Paquetes AUR (pkgs-aur.txt) — los -bin pueden tardar"
# Uno por uno y sin abortar. El AUR es infra comunitaria y falla seguido:
# paquete borrado, PKGBUILD que no compila, "Connection reset by peer" al
# clonar. Con la lista entera en un solo yay, UN fallo mata el bootstrap por
# el set -e y no llegan a correr los pasos 4..10 (IgnoreGroup, libvirt, npm...).
aur_fallidos=()
# El PKGBUILD se lee por el fd 3, NO por stdin: yay hereda stdin y si la lista
# viniera por ahí se comería los paquetes que faltan leer. stdin queda libre
# para la terminal (contraseña de sudo).
while read -r pkg <&3; do
	# Un reintento: la mayoría de los fallos del AUR son de red y pasan solos.
	yay -S --needed --noconfirm "$pkg" ||
		yay -S --needed --noconfirm "$pkg" ||
		aur_fallidos+=("$pkg")
done 3< <(grep -v '^\s*#' pkgs-aur.txt | grep -v '^\s*$')

echo "==> [4/10] Proteger paquetes de end-4 de pacman -Syu (IgnoreGroup)"
grep -q '^IgnoreGroup *=.*illogical-impulse' /etc/pacman.conf ||
	sudo sed -i '/^\[options\]/a IgnoreGroup = illogical-impulse' /etc/pacman.conf

echo "==> [5/10] Virtualización: servicio libvirt + grupo de usuario"
sudo systemctl enable libvirtd.service
sudo usermod -aG libvirt "$USER"

echo "==> [6/10] npm global en el home (sin sudo, evita errores de permisos)"
mkdir -p ~/.local/share/npm-global
npm config set prefix ~/.local/share/npm-global

echo "==> [7/10] Claude Code (instalador oficial)"
command -v claude >/dev/null || [ -x ~/.local/bin/claude ] ||
	curl -fsSL https://claude.ai/install.sh | bash

echo "==> [8/10] Tema de fastfetch con imágenes (LierB)"
[ -d ~/.local/share/fastfetch ] ||
	git clone https://github.com/LierB/fastfetch ~/.local/share/fastfetch

echo "==> [9/10] Carpetas de imágenes"
mkdir -p ~/Pictures/{Wallpapers,Screenshots,FastfetchLogos}

echo "==> [10/10] Identidad de git (solo si no existe) y permisos de scripts"
git config --global user.name >/dev/null 2>&1 || git config --global user.name "Ander0296"
git config --global user.email >/dev/null 2>&1 || git config --global user.email "165844215+Ander0296@users.noreply.github.com"
chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true

echo ""
# El resumen va al final para que no se pierda entre miles de líneas de yay.
if [ ${#aur_fallidos[@]} -gt 0 ]; then
	echo "OJO — paquetes AUR que NO se instalaron (${#aur_fallidos[@]}):"
	printf '  · %s\n' "${aur_fallidos[@]}"
	echo "  Probá 'yay -S <paquete>' a mano: si dice 'No AUR package found'"
	echo "  el paquete se borró del AUR y hay que actualizar pkgs-aur.txt."
	echo ""
fi

echo "Bootstrap listo. El grupo libvirt aplica al próximo login."
echo "Siguen los pasos manuales del README (fase 9):"
echo "  1Password + SSH agent · remoto a SSH · claude login · gentle-ai · nvim · secrets.fish · wallpapers"
