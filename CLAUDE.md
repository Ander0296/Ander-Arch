## Proyecto: Ander-Arch — mi ~/.config versionado (Arch + Hyprland end-4 + stack de IA)

Objetivo: entender el estado actual de TODA mi configuración y seguir
personalizándola con Claude Code como guía: Hyprland (Lua), Quickshell (QML),
fish, kitty, yazi, scripts. Este repo se replica idéntico en varios PCs:
cada cambio versionado impacta en todos.

### Reglas de trabajo
- Yo escribo el código a mano. Claude Code NO ejecuta bash ni crea/edita
  archivos directamente salvo que yo lo pida explícitamente en el mensaje.
- SÍ podés ejecutar comandos de solo lectura para explorar (ls, find, cat, rg,
  git log, git diff, git status, pacman -Q) sin pedir permiso.
- Antes de proponer un cambio: explicá qué hace cada línea con un comentario
  y dame el bloque completo listo para pegar, indicando archivo y ubicación exacta.
- Estoy aprendiendo en profundidad: explicaciones detalladas, paso a paso,
  con analogías cuando ayuden. No asumas que ya conozco un concepto.
- Priorizar simplicidad y soluciones directas; testear en alcance chico
  antes de aplicar a gran escala.
- Mi shell es fish: nunca sugieras heredocs (<<EOF); usar printf o nano.

### Reglas propias de este repo (importantes)
- Cambio versionado = cambio en TODOS mis PCs. Avisame cuando una propuesta
  tenga impacto multi-máquina (ej: el blur está apagado a propósito en
  hypr/custom/general.lua por la iGPU del PC original).
- Paquete nuevo instalado → agregarlo a pkgs-pacman.txt o pkgs-aur.txt
  + commit. Nunca dejar un paquete sin registrar.
- NO tocar ni proponer versionar: fish/conf.d/secrets.fish (secretos),
  hypr/monitors.lua y hypr/workspaces.lua (por máquina), y los colores
  generados por matugen. Están ignorados a propósito.
- El .gitignore es whitelist (/* al inicio): un archivo nuevo en la raíz
  necesita su línea !/archivo para versionarse.
- En hypr/: la carpeta hyprland/ es la base de end-4; MIS cambios van
  siempre en hypr/custom/ (env, execs, general, keybinds, rules, variables).
- Quickshell: quickshell/ii/scripts/colors/applycolor.sh tiene mi fix
  (apply_anyterm desactivado); upstream lo pisa al actualizar end-4.
- Teclado dvorak-alt-intl: tenerlo en cuenta al proponer keybinds.
- Commits en español, mensaje corto de qué cambié.

### Estructura modular
- hypr/ → Hyprland 0.55 en Lua nativo (NO hyprlang/.conf viejo).
- quickshell/ → shell gráfico illogical-impulse completo (QML).
- fish/ → config.fish, functions/ y todo conf.d/.
- nvim/ → LazyVim; tiene su PROPIO CLAUDE.md y project de Engram ("nvim").
  Para trabajo enfocado en Neovim, abrir claude parado en esa carpeta.
- bootstrap.sh + pkgs-*.txt + README.md → sistema de replicación multi-PC.

### Engram
- El project es ".config" (basename real de esta carpeta, NO inventar otro
  nombre). Guardá ahí el inventario inicial y cada decisión que tomemos.

### CodeGraph
- Activo en este proyecto (.codegraph/ presente). Usar codegraph_explore
  para navegación de código antes de grep/Read.
- .codegraph/ NO se versiona (lo ignora el /*): en cada PC nuevo hay que
  correr `codegraph init` una vez.
