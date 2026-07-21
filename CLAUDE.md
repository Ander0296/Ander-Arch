## Proyecto: Ander-Arch — README de replicación exacta del sistema
- Objetivo: documentar en README.md (raíz del repo) el paso a paso COMPLETO para
  clonar este sistema Arch + Hyprland (end-4/dots-hyprland) + stack de IA
  (Claude Code + gentle-ai + Engram + CodeGraph) en cualquier PC nuevo, sea
  igual de hardware (Intel i5-1035G1 + NVIDIA MX330) o distinto (Intel sin
  dedicada, AMD, etc).
- Fuente de verdad: las guías ya escritas (guia-instalacion.md, Hyprland_Guia.txt,
  Nvim_Guia.txt, Yazi_Guia.txt) están pegadas/adjuntas en esta sesión. Usalas
  como base, NO reinventes pasos que ya están ahí — tu trabajo es consolidar,
  no volver a escribir desde cero.
- El repo YA versiona: hypr, kitty, fish, quickshell/ii, fuzzel, mpv, foot,
  wlogout, matugen, Kvantum, kde-material-you-colors, fontconfig,
  xdg-desktop-portal, zshrc.d, nvim, starship.toml.
- El repo NO versiona (hay que agregarlo o reconstruirlo a mano):
  - yazi/ (falta por completo, agregar al .gitignore allow-list y al repo)
  - ~/.claude/CLAUDE.md global (config de gentle-ai) — no es un dotfile de
    ~/.config, documentar su contenido aparte en el README
  - 1Password (~/.config/1password/ssh/agent.toml) — documentar contenido,
    no asumir que se clona
- Reglas de trabajo: yo escribo el código a mano. Claude Code NO ejecuta bash
  ni crea/edita archivos directamente salvo que yo lo pida explícitamente.
- El README.md debe separar CLARAMENTE tres tipos de pasos:
  1. Pasos universales (cualquier PC): archinstall, yay, dots-hyprland, Claude
     Code, gentle-ai, CodeGraph, LazyVim, herramientas CLI (bat, sd, git-delta,
     tealdeer, btop, fastfetch, zoxide, ripgrep, fd, fzf, etc).
  2. Pasos condicionales por hardware (detectar antes con lscpu/lspci):
     - Intel iGPU → mesa, lib32-mesa, vulkan-intel, lib32-vulkan-intel
     - AMD iGPU/dGPU → mesa, lib32-mesa, vulkan-radeon, lib32-vulkan-radeon
     - NVIDIA dedicada legacy (Pascal/Maxwell/Volta, como la MX330) →
       nvidia-580xx-dkms (AUR) — NO nvidia-open
     - NVIDIA dedicada moderna (Turing+) → nvidia-open normal
     - Sin GPU dedicada → saltar toda la fase de drivers NVIDIA
  3. Pasos de "clonar dotfiles" (git clone del repo a ~/.config) vs pasos de
     "instalar paquetes" (pacman/yay/npm) — son categorías distintas, no mezclar.
- Comentarios en cada línea de código relevante del README (bash) explicando
  qué hace, igual que en las guías fuente.
- Estructura modular esperada del README.md: una FASE por sección, igual
  numeración que guia-instalacion.md, agregando la fase 0 de detección de
  hardware al principio.
- Engram: el project es "Ander-Arch" (basename de esta carpeta, NO inventar
  otro nombre).
