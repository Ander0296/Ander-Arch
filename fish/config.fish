# Commands to run in interactive sessions can go here
if status is-interactive
    # No greeting
    set fish_greeting

    # Use starship
    function starship_transient_prompt_func
        starship module character
    end
    if test "$TERM" != linux
        starship init fish | source
        enable_transience
    end

    # Colors
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end
    # Fastfetch con logo random, disparado en el primer prompt (no durante la carga del rc)
    # para evitar la carrera con la negociación del protocolo gráfico de kitty
    function __fastfetch_on_first_prompt --on-event fish_prompt
        functions -e __fastfetch_on_first_prompt  # se autoelimina: solo corre una vez por sesión
        if test "$TERM" = xterm-kitty
            fastfetch-random
        end
    end

    # Aliases
    # Personales
    alias trad 'trans -b :es' # sintaxis nativa de fish, sin "="
    # kitty doesn't clear properly so we need to do this weird printing
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias pamcan pacman
    alias q 'qs -c ii'
    if test "$TERM" != linux
        alias ls 'eza --icons'
    end
    if test "$TERM" = xterm-kitty
        alias ssh 'kitten ssh'
    end
end
