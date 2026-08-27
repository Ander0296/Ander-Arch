function fastfetch-random --description "Fastfetch con imagen aleatoria en vez de ascii art"
    set -l logos_dir ~/Pictures/FastfetchLogos
    set -l logos (fd -e png -e jpg -e jpeg . $logos_dir 2>/dev/null)

    # Guarda multi-PC: esa carpeta NO esta en el repo. En una maquina nueva
    # `fd` no devuelve nada y `random choice` sin argumentos tira error.
    if test (count $logos) -eq 0
        fastfetch --config groups --logo none
        return
    end

    # Ancho REAL de la ventana en este instante (tput se lo pregunta a la tty).
    set -l cols (tput cols)

    # Por debajo de ~70 columnas no entra ni el logo chico junto al texto:
    # mejor mostrar solo la info que ver la imagen pisada por letras.
    if test $cols -lt 70
        fastfetch --config groups --logo none
        return
    end

    set -l logo (random choice $logos)

    # 28x14 celdas = 280x308 px con JetBrainsMono 12pt (celda ~10x22).
    # Calculado para que TODO entre en 85 columnas y kitty nunca tenga que
    # re-partir una linea al retilear: 28 + 3 + 5 (key) + 4 (sep) + 42 = 82.
    fastfetch --config groups \
        --logo $logo \
        --logo-type kitty \
        --logo-width 28 \
        --logo-height 14 \
        --logo-padding-top 4 \
        --logo-padding-right 3
end
