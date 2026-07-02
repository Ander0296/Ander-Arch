#!/usr/bin/env bash
# Cambia el wallpaper cada 1 hora, eligiendo una imagen al azar de ~/Pictures/Wallpapers
WALLPAPERS_DIR="$HOME/Pictures/Wallpapers"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"

while true; do
  sleep 3600                                                      # 1 hora en segundos
  img=$(fd -e png -e jpg -e jpeg . "$WALLPAPERS_DIR" | shuf -n 1) # elige 1 imagen al azar
  if [[ -n "$img" ]]; then
    "$SWITCHWALL" --image "$img" # aplica wallpaper + recalcula colores del tema (matugen)
  fi
done
