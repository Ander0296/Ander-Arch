function sync-repos --description "Fetch + pull seguro de todos mis repos (config + Proyectos)"
    # Mi usuario de GitHub: es el criterio de "este repo es mío".
    set -l usuario Ander0296

    # ~/.config va sí o sí y primero: es el que se replica en todos los PCs.
    # Si algún día el escaneo fallara, este no se pierde.
    set -l repos $HOME/.config

    # El resto los descubro por dueño, no por ruta fija. Antes tenía
    # ~/Proyectos hardcodeado y se me escapó ~/Pictures (los wallpapers).
    # Filtrar por el remoto deja afuera solos a los de terceros (end-4, yay,
    # sddm, plugins de yazi) sin tener que enumerarlos, y mete los míos
    # nuevos estén donde estén.
    # -H incluye ocultos, -I ignora los .gitignore (si no, no encuentra
    # ~/.config, que se ignora a sí mismo), -d 5 acota la profundidad.
    for gitdir in (fd -H -I -t d -d 5 '^\.git$' $HOME \
            -E .cache -E .local -E .claude -E node_modules -E .venv -E target 2>/dev/null | sort)
        set -l repo (string replace -r '/\.git/?$' '' $gitdir)
        contains -- $repo $repos; and continue # ya está (el ~/.config de arriba)
        set -l url (git -C $repo remote get-url origin 2>/dev/null)
        # Matchea tanto git@github.com:Usuario/ como https://github.com/Usuario/
        string match -qr "github\.com[:/]$usuario/" -- "$url"; and set -a repos $repo
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
