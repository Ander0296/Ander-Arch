function sync-repos --description "Fetch + pull seguro de todos mis repos (config + Proyectos)"
    # ~/.config primero (es el que se replica en todos los PCs), después cada
    # subcarpeta de ~/Proyectos que tenga .git adentro. Los proyectos nuevos
    # entran solos, sin tocar el script. Quedan afuera a propósito los repos
    # de terceros (~/dots-hyprland, ~/yay, el tema de SDDM, la caché de yay):
    # pullear el upstream de end-4 pisaría mis fixes de Quickshell.
    set -l repos $HOME/.config
    for d in $HOME/Proyectos/*
        test -d $d/.git; and set -a repos $d
    end

    set -l problemas 0 # si termina en >0, hay algo para mirar a mano

    for repo in $repos
        set -l nombre (string replace $HOME '~' $repo) # ~/... queda más corto de leer

        # Traigo el estado del remoto. fetch NO toca el working tree: es seguro siempre.
        if not git -C $repo fetch --quiet origin 2>/dev/null
            printf '  x %-34s no pude contactar el remoto\n' $nombre
            set problemas (math $problemas + 1)
            continue
        end

        # Sin upstream configurado no hay con qué comparar. Comillas en '@{u}'
        # porque fish expande las llaves si van sueltas.
        if not git -C $repo rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1
            printf '  ~ %-34s sin upstream, lo salteo\n' $nombre
            continue
        end

        set -l atrasado (git -C $repo rev-list --count 'HEAD..@{u}') # commits que me faltan traer
        set -l adelantado (git -C $repo rev-list --count '@{u}..HEAD') # commits míos sin pushear

        if test $atrasado -gt 0 -a $adelantado -gt 0
            # Commits en los dos lados. NO pulleo solo: aviso y decide el humano.
            printf '  ! %-34s DIVERGIDO (%s local / %s remoto) - resolvelo a mano\n' $nombre $adelantado $atrasado
            set problemas (math $problemas + 1)
        else if test $atrasado -gt 0
            # Fast-forward puro: imposible que genere conflicto. Y si hay archivos
            # sucios que el pull pisaría (el config.json vivo de Quickshell),
            # git aborta solo en vez de romper nada.
            if git -C $repo pull --ff-only --quiet
                printf '  v %-34s actualizado (+%s)\n' $nombre $atrasado
            else
                printf '  x %-34s no pude pullear (cambios sin commitear?)\n' $nombre
                set problemas (math $problemas + 1)
            end
        else if test $adelantado -gt 0
            printf '  ^ %-34s %s commit(s) sin pushear\n' $nombre $adelantado
        else
            printf '  = %-34s al dia\n' $nombre
        end
    end

    # El return explícito importa: sin él la función devuelve el exit code del
    # último test, o sea 1 justo cuando NO hubo problemas. Así queda al revés
    # de lo esperado y rompe cualquier `sync-repos; and otra-cosa`.
    if test $problemas -gt 0
        printf '\n%s repo(s) necesitan atencion.\n' $problemas
        return 1
    end
    return 0
end
