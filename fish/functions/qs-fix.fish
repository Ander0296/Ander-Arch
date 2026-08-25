function qs-fix --description "Recompila Quickshell cuando un update de Qt6 lo deja roto"
    # PKGBUILD local de end-4. OJO: no está en AUR, yay -S falla con "No AUR package found".
    set -l pkgdir ~/dots-hyprland/sdata/dist-arch/illogical-impulse-quickshell-git

    # 1. Ping disfrazado: TEST_ALIVE no existe, pero si el socket IPC responde el exit es 0.
    if qs -c ii ipc call TEST_ALIVE >/dev/null 2>&1
        echo "✓ Quickshell responde. No hay nada que recompilar."
        return 0
    end

    # 2. Sin el repo dots-hyprland clonado no hay PKGBUILD con qué reconstruir.
    if not test -d $pkgdir
        echo "✗ Falta $pkgdir — cloná dots-hyprland en esta máquina primero."
        return 1
    end

    # 3. -f fuerza el rebuild (ya existe el .pkg.tar.zst), -s trae makedepends,
    #    -i instala, -C limpia src/ para que CMake reconfigure contra el Qt6 ACTUAL.
    echo "✗ Quickshell roto (Qt6 se actualizó). Recompilando, tarda 5-15 min..."
    pushd $pkgdir
    makepkg -fsiC
    set -l ok $status   # guardo el status ANTES de popd, que lo pisa
    popd

    # 4. El proceso viejo sigue con las libs viejas mapeadas en RAM: hay que matarlo.
    if test $ok -eq 0
        echo "✓ Listo. Apretá CTRL+SUPER+R para reiniciar los widgets."
    end
    return $ok
end
