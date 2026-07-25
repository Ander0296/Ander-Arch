#!/usr/bin/env bash
# Activa/desactiva el cambio automático de wallpaper (random-wallpaper-loop.sh)
LOOP_SCRIPT="$HOME/.config/hypr/scripts/random-wallpaper-loop.sh"

if pgrep -f "$LOOP_SCRIPT" > /dev/null; then
  pkill -f "$LOOP_SCRIPT" # ya está corriendo: lo detiene
  notify-send "Wallpaper automático" "Desactivado" -a "Hyprland"
else
  nohup bash "$LOOP_SCRIPT" > /dev/null 2>&1 & disown # no estaba corriendo: lo arranca en background
  notify-send "Wallpaper automático" "Activado (cambia cada 1 hora)" -a "Hyprland"
fi
