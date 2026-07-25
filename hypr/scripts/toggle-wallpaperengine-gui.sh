#!/usr/bin/env bash
# Muestra/oculta wallpaperengine-gui en su scratchpad (special:wallpaperengine).
# No usamos on_created_empty porque con persistent=true el workspace especial
# ya existe vacío desde el arranque, así que ese evento nunca se dispara.

if pgrep -f '^wallpaperengine-gui$' > /dev/null; then
	# Ya está corriendo: solo mostrar/ocultar, nunca se cierra ni se relanza.
	# Anclado con ^...$ para no matchear el propio nombre de este script.
	hyprctl dispatch 'hl.dsp.workspace.toggle_special("wallpaperengine")'
else
	# Primera vez (o se cerró manualmente): lanzarla directo dentro del scratchpad.
	# hl.dsp.exec_cmd (no el "dispatch exec" clásico) es lo que entiende este fork Lua de Hyprland.
	hyprctl dispatch 'hl.dsp.exec_cmd("[workspace special:wallpaperengine; float; size 1200 700; center] wallpaperengine-gui")'
fi
