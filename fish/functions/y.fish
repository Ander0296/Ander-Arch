function y --description "Abre yazi; al salir, la terminal queda en la carpeta donde navegaste"
    set tmp (mktemp -t "yazi-cwd.XXXXXX") # archivo temporal donde yazi escribe su cwd final
    yazi $argv --cwd-file="$tmp" # --cwd-file: yazi vuelca ahí la ruta al salir
    if set cwd (cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        cd -- "$cwd" # solo si cambió, evita un cd innecesario
    end
    rm -f -- "$tmp" # limpieza del temporal
end
