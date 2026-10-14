#!/usr/bin/env bash
# Menú de fuzzel para elegir por dónde sale el audio (HDMI, jack, Bluetooth, USB...).
# Muestra TODOS los perfiles de salida de TODAS las placas, no solo las salidas que
# existen ahora: así aparece el jack aunque la placa esté en modo HDMI (o al revés).

# Imprime el nombre del sink (la salida) que pertenece a la placa $1, si existe
sink_de_placa() {
  pactl -f json list sinks \
    | jq -r --arg c "$1" '[.[] | select(.properties["device.name"] == $c)][0].name // empty'
}

# Una línea por salida posible: placa <TAB> perfil <TAB> perfil activo <TAB> texto del menú
opciones=$(pactl -f json list cards | jq -r '
  .[]
  | .name as $card
  | (.properties["device.description"] // $card) as $cdesc
  | .active_profile as $act
  | [.profiles | to_entries[]
     | select(.value.sinks > 0 and .value.available and .key != "pro-audio")
     | . + {out: (.key | split("+")[0])}]
  | group_by(.out)[] | max_by(.value.priority)
  | (if ($card | startswith("bluez")) then                    # Bluetooth: nombre del auricular
       "🎧 " + $cdesc + (if (.key | test("headset|handsfree")) then " (modo llamada)" else "" end)
     elif (.out | test("hdmi")) then                         # HDMI: "HDMI", "HDMI 2"...
       "📺 " + ((.value.description | capture("(?<h>HDMI[^)]*)").h) // "HDMI")
     elif (.out | test("analog")) then                       # jack de la placa
       "🎧 Jack (audífonos / parlantes)"
     else "🔊 " + $cdesc end) as $label                      # USB u otros: nombre del dispositivo
  | [$card, .key, $act, (if .key == $act then "● " else "○ " end) + $label]
  | @tsv')

[ -z "$opciones" ] && { notify-send "Salida de audio" "No encontré salidas" -a "Hyprland"; exit 1; }

# Muestra solo el texto en fuzzel; con Esc sale sin hacer nada
eleccion=$(printf '%s\n' "$opciones" | cut -f4 | fuzzel --dmenu --prompt "Salida de audio: ") || exit 0

linea=$(printf '%s\n' "$opciones" | awk -F'\t' -v e="$eleccion" '$4 == e {print; exit}')
placa=$(printf '%s' "$linea" | cut -f1)
perfil=$(printf '%s' "$linea" | cut -f2)
activo=$(printf '%s' "$linea" | cut -f3)

viejo=$(sink_de_placa "$placa")
[ "$perfil" != "$activo" ] && pactl set-card-profile "$placa" "$perfil" # mueve la "perilla" solo si hace falta

# Espera hasta 2 s a que aparezca la salida nueva
for _ in $(seq 20); do
  sink=$(sink_de_placa "$placa")
  [ -n "$sink" ] && { [ "$perfil" = "$activo" ] || [ "$sink" != "$viejo" ]; } && break
  sleep 0.1
done

[ -z "$sink" ] && { notify-send "Salida de audio" "No apareció la salida elegida" -a "Hyprland"; exit 1; }

pactl set-default-sink "$sink" # lo que suena se muda a la salida nueva
notify-send "Salida de audio" "$(printf '%s' "$eleccion" | sed 's/^[●○] *//')" -a "Hyprland"
