function fastfetch-random --description "Fastfetch con imagen aleatoria en vez de ascii art"
    set -l logos_dir ~/Pictures/FastfetchLogos
    set -l logos (fd -e png -e jpg -e jpeg . $logos_dir)
    set -l logo (random choice $logos)
    fastfetch --config groups --logo $logo --logo-type kitty --logo-width 40 --logo-height 17 --logo-padding-top 4
end
