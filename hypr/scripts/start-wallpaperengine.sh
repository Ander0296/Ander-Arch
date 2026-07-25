#!/usr/bin/env bash
# Arranca linux-wallpaperengine al iniciar Hyprland, replicando la última
# asignación por monitor guardada por wallpaperengine-gui (o el último
# wallpaper usado, si Multi-Monitor está desactivado en la GUI).
# Si esta PC no tiene el motor instalado (no se versiona por máquina),
# no hace nada y no rompe el arranque.

CONFIG="$HOME/.config/wallpaperengine-gui/config.ini"

command -v linux-wallpaperengine >/dev/null 2>&1 || exit 0
[[ -f "$CONFIG" ]] || exit 0

# Lee "key" dentro de la sección "[section]" del ini (formato QSettings de Qt).
# Pasa section/key por ENVIRON (no por -v) porque las claves tipo
# "screen_assignments\1\screen" tienen barras invertidas que -v reinterpreta
# como escapes y las rompe.
section_get() {
	local section="$1" key="$2"
	SECTION_GET_S="[$section]" SECTION_GET_K="$key" awk -F'=' '
		$0 ~ /^\[/ { insec = ($0 == ENVIRON["SECTION_GET_S"]) }
		insec && $1 == ENVIRON["SECTION_GET_K"] { sub(/^[^=]*=/, ""); print; exit }
	' "$CONFIG"
}

scaling=$(section_get engine_defaults scaling)
clamp=$(section_get engine_defaults clamping)
fps=$(section_get engine_defaults fps)
silent=$(section_get engine_defaults silent)
no_fullscreen_pause=$(section_get engine_defaults no_fullscreen_pause)

opts=(--scaling "${scaling:-fill}" --clamp "${clamp:-border}" --fps "${fps:-30}")
[[ "$silent" == "true" ]] && opts+=(--silent)
[[ "$no_fullscreen_pause" == "true" ]] && opts+=(--no-fullscreen-pause) # si no, hyprlock (fullscreen) lo pausa al bloquear la pantalla

args=()
if [[ "$(section_get multi_monitor enabled)" == "true" ]]; then
	count=$(section_get multi_monitor 'screen_assignments\size')
	for i in $(seq 1 "${count:-0}"); do
		screen=$(section_get multi_monitor "screen_assignments\\${i}\\screen")
		bg=$(section_get multi_monitor "screen_assignments\\${i}\\wallpaper")
		[[ -n "$screen" && -n "$bg" ]] && args+=(--screen-root "$screen" --bg "$bg")
	done
else
	last=$(section_get "%General" last_wallpaper)
	[[ -n "$last" ]] && args=("$last")
fi

[[ ${#args[@]} -eq 0 ]] && exit 0

nohup linux-wallpaperengine "${opts[@]}" "${args[@]}" >/dev/null 2>&1 &
disown
