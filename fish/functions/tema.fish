# tema: muestra qué tema de kitty está puesto ahora (para cambiarlo: temas).
function tema --description 'Mostrar el tema actual de kitty'
    set -l archivo ~/.config/kitty/current-theme.conf # kitty guarda acá el tema elegido
    if test -f $archivo
        # la línea "## name: Terafox" trae el nombre: me quedo solo con lo que va después de "## name: "
        string replace -r '^## name: ' '' -- (string match -r '^## name: .*' < $archivo)[1]
    else
        echo "Sin tema: kitty usa sus colores por defecto"
    end
end
