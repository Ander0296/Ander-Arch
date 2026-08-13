function md2pdf --description "Convierte Markdown a PDF con pandoc + motor typst"
    # Sin argumentos no hay nada que convertir: muestro el uso y salgo con error.
    if test (count $argv) -eq 0
        printf 'uso: md2pdf archivo.md [otro.md ...]\n'
        return 1
    end

    # Si falta alguna de las dos piezas, el error que tira pandoc es críptico.
    # Prefiero decirlo claro yo.
    for prog in pandoc typst
        if not command -q $prog
            printf '  x falta %s -> sudo pacman -S pandoc-cli typst\n' $prog
            return 1
        end
    end

    set -l fallos 0

    for md in $argv
        if not test -f $md
            printf '  x %s no existe\n' $md
            set fallos (math $fallos + 1)
            continue
        end

        # El PDF sale al lado del .md, con su mismo nombre.
        # El $ del regex ancla la extensión al FINAL: así un archivo llamado
        # "notas.md.viejo.md" cambia solo la última, no la primera.
        set -l pdf (string replace -r '\.md$' '.pdf' -- $md)

        # --pdf-engine=typst: el motor que arma las páginas. Sin esta bandera
        #   pandoc busca LaTeX por defecto, que no tengo (y son varios GB).
        # -V mainfont: OBLIGATORIO. La plantilla de pandoc solo emite la lista
        #   de fuentes si esta variable existe; sin ella typst 0.15 aborta con
        #   "font fallback list must not be empty". Ver `typst fonts` para otras.
        # --resource-path: las imágenes del .md se referencian relativas AL
        #   ARCHIVO, no a la carpeta donde estoy parado al ejecutar el comando.
        if pandoc $md -o $pdf --pdf-engine=typst \
                -V mainfont="DejaVu Serif" \
                --resource-path=(dirname -- $md)
            printf '  v %s\n' $pdf
        else
            printf '  x fallo al convertir %s\n' $md
            set fallos (math $fallos + 1)
        end
    end

    # Mismo cuidado que en sync-repos: sin return explícito la función devuelve
    # el exit code del último comando que corrió, y queda justo al revés.
    if test $fallos -gt 0
        return 1
    end
    return 0
end
