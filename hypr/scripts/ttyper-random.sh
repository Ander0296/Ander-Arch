#!/usr/bin/env bash
# Frases de mecanografía: UN archivo POR FRASE en ~/.config/ttyper/texts (ttyper corre
# todo el archivo como un solo test, por eso no se juntan frases en un mismo archivo).
# Claude las vuelca desde el MECANOGRAFIA.md de cada proyecto al cerrar cada tanda.
# "r" en ttyper reinicia el MISMO archivo (comportamiento fijo de la herramienta).
# "q" para salir: acá afuera relanzamos con otro archivo al azar, sin cerrar la ventana.

while true; do
  file=$(fd -e txt . "$HOME/.config/ttyper/texts" 2>/dev/null | shuf -n 1)
  if [[ -n "$file" ]]; then
    ttyper "$file"
  else
    ttyper -l spanish # fallback si todavía no existe ninguna frase
  fi
done
