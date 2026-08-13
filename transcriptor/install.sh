#!/usr/bin/env bash
# Instalador del transcriptor. Se corre UNA vez por PC.
#
# El motor principal es Groq (nube): no necesita nada pesado, solo curl y la
# clave. El entorno de Python y el modelo local son el RESPALDO para cuando no
# hay internet — pesan ~1 GB y por eso viven fuera del repo, en
# ~/.local/share/transcriptor/.
#
#   bash install.sh            → todo (Groq + respaldo local)
#   bash install.sh --sin-local → solo Groq, sin descargar el modelo
set -euo pipefail

BASE="$HOME/.local/share/transcriptor"
VENV="$BASE/venv"
CONFIG="$HOME/.config/transcriptor"
BIN="$HOME/.local/bin"
CLAVE="$BASE/groq.key"
SIN_LOCAL="${1:-}"

mkdir -p "$BASE" "$BIN"

echo "==> 1/5  Verificando dependencias del sistema"
for cmd in pw-record pactl pw-dump notify-send curl fuzzel; do
  if ! command -v "$cmd" >/dev/null; then
    echo "FALTA '$cmd'. Instalalo antes de seguir (ver README)." >&2
    exit 1
  fi
done

echo "==> 2/5  Clave de Groq"
if [[ -s "$CLAVE" ]]; then
  echo "    ya hay una clave en $CLAVE (no la toco)"
else
  echo "    Pegá tu API key de Groq (empieza con gsk_) y dale Enter."
  echo "    Se saca en https://console.groq.com/keys — dejala vacía para usar solo el motor local."
  read -rsp "    Clave: " GROQ_KEY
  echo
  if [[ -n "$GROQ_KEY" ]]; then
    printf '%s\n' "$GROQ_KEY" > "$CLAVE"
    # 600 = solo tu usuario puede leerla. Y vive FUERA de ~/.config, que es un
    # repo público: dentro, un `git add -A` distraído la publicaría.
    chmod 600 "$CLAVE"
    echo "    guardada en $CLAVE (permisos 600)"
  else
    echo "    sin clave: se usará el motor local"
  fi
fi

if [[ "$SIN_LOCAL" == "--sin-local" ]]; then
  echo "==> 3/5  Respaldo local: OMITIDO (--sin-local)"
  echo "==> 4/5  Respaldo local: OMITIDO"
else
  echo "==> 3/5  Entorno de Python 3.12 para el respaldo local"
  # Python 3.12 y no el del sistema: las ruedas precompiladas de ctranslate2
  # tardan meses en salir para cada versión nueva de Python. uv se baja el 3.12
  # solo, sin tocar el Python del sistema.
  if command -v uv >/dev/null; then
    uv venv --python 3.12 "$VENV"
    uv pip install --python "$VENV/bin/python" faster-whisper
    echo "==> 4/5  Descargando el modelo local de respaldo (cientos de MB)"
    "$VENV/bin/python" "$CONFIG/transcriptor.py" descargar-modelo --modelo small
  else
    echo "    'uv' no está instalado: me salto el respaldo local."
    echo "    Para tenerlo: sudo pacman -S uv && bash install.sh"
  fi
fi

echo "==> 5/5  Dejando el comando 'transcriptor' en el PATH"
chmod +x "$CONFIG/transcriptor" "$CONFIG/transcriptor.py"
ln -sf "$CONFIG/transcriptor" "$BIN/transcriptor"

if ! command -v transcriptor >/dev/null; then
  echo "    OJO: $BIN no está en tu PATH. En fish: fish_add_path ~/.local/bin"
fi

echo
echo "Listo. Comprobá qué motor va a usar:"
echo "    transcriptor motor"
echo
echo "Y después:"
echo "    transcriptor elegir      # o el atajo CTRL+SUPER+ALT+P"
echo "    transcriptor alternar    # o el atajo CTRL+SUPER+ALT+R"
