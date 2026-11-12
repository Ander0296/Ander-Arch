# temas: ver y cambiar el tema de kitty.
#   temas              → abre el catálogo con vista previa en vivo (↑↓ recorrer, / buscar,
#                        Enter elegir, Esc salir sin cambiar nada)
#   temas "Terafox"    → aplica ese tema directo, sin abrir el catálogo
# Elegir un tema reescribe kitty/kitty.conf y kitty/current-theme.conf (están en el repo).
function temas --description 'Ver y cambiar el tema de kitty'
    if test (count $argv) -eq 0 # sin argumentos: abrir el catálogo
        kitty +kitten themes --reload-in=all # --reload-in=all: todas las ventanas toman el tema al elegirlo
    else # con un nombre: aplicarlo directo
        kitty +kitten themes --reload-in=all $argv
    end
end
