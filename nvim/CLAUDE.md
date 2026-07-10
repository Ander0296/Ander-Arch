## Proyecto: configuración de Neovim (LazyVim)

### Qué es y objetivo
- Configuración personal de Neovim basada en LazyVim, versionada dentro del
  repo de dotfiles (~/.config es el repo git; esta carpeta es nvim/ adentro).
- Objetivo: seguir configurando LazyVim en profundidad (opciones, keymaps,
  plugins, LSP) mientras aprendo. Cada cambio debe dejar aprendizaje, no
  solo funcionar.

### Reglas de trabajo (obligatorias)
- El usuario escribe TODO el código a mano dentro de nvim. Claude NO ejecuta
  bash ni crea/edita archivos directamente, salvo pedido explícito.
- Claude SÍ puede leer archivos del proyecto para entender el estado actual
  antes de proponer cualquier cambio.
- Cada línea de código relevante que Claude indique lleva comentario --
  explicando qué hace.
- Un concepto por vez, en pasos chicos: explicar → el usuario aplica →
  se verifica en nvim → recién ahí se avanza. Simplicidad por sobre
  workarounds complejos; probar en chico antes de generalizar.
- El usuario está aprendiendo: explicar en detalle, con analogías cuando
  ayuden, sin asumir conceptos previos de Vim/Neovim.

### Estructura modular (convenciones LazyVim)
- init.lua y lua/config/lazy.lua son el bootstrap: NO se tocan salvo
  necesidad justificada.
- Opciones → lua/config/options.lua · keymaps → lua/config/keymaps.lua ·
  autocmds → lua/config/autocmds.lua.
- Plugins: un archivo por plugin (o grupo temático) en lua/plugins/.
- Antes de proponer un plugin nuevo, revisar si existe un extra oficial
  de LazyVim (:LazyExtras) que lo cubra.
- lazy-lock.json se versiona SIEMPRE: si cambia tras :Lazy update, entra
  en el commit. En otros PCs se aplica con :Lazy restore.
- Los commits se hacen desde ~/.config (raíz del repo), no desde esta carpeta.

### Entorno
- Arch Linux + Hyprland 0.55 (end-4/dots-hyprland), terminal kitty, shell fish.
- Teclado dvorak-alt-intl: considerar la ergonomía REAL de los keymaps
  (las posiciones físicas no son las de qwerty).
- Fuente JetBrains Mono Nerd instalada (iconos ok) · clipboard Wayland
  vía wl-clipboard.
- LSP vía Mason (se instalan al abrir cada lenguaje). Lenguajes prioritarios:
  Java (aprendiendo; jdk-openjdk + maven instalados) y Lua (config Hyprland).
- avante.nvim ya configurado (IA in-editor con GEMINI_API_KEY desde
  fish/conf.d/secrets.fish, fuera de git). Claude Code no lo reemplaza:
  esta sesión es para configurar y aprender, avante es asistencia al editar.

### Memoria
- Engram: el project es "nvim" (basename de esta carpeta, NO inventar
  otro nombre). Guardar ahí cada decisión de configuración con una nota
  corta del porqué.
- CodeGraph: NO activo en este proyecto (config chica, specs independientes).
  Reevaluar con codegraph init solo si lua/plugins/ crece mucho y aparecen
  módulos que se requieren entre sí.
