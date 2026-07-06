## Proyecto: personalizar nvim sobre base LazyVim

Objetivo: entender el estado actual de mi configuración de Neovim (base LazyVim,
https://www.lazyvim.org/, con algunos cambios mínimos ya hechos) y seguir
personalizándola a mi gusto (keymaps, plugins, opciones), manteniendo LazyVim
como base y no reescribiendo todo desde cero.

### Reglas de trabajo
- Yo escribo el código a mano. Claude Code NO ejecuta bash ni crea/edita archivos
  directamente salvo que yo lo pida explícitamente en el mensaje.
- SÍ podés ejecutar comandos de solo lectura para explorar (ls, find, cat, git log,
  git diff, which, pacman -Q) sin pedir permiso — entender el estado actual es el
  objetivo principal de este proyecto.
- Antes de proponer cualquier cambio, explicá qué hace cada línea con un comentario,
  y dame el bloque completo para que yo lo pegue donde corresponda.
- Estoy aprendiendo en profundidad: explicaciones detalladas, paso a paso, con
  analogías cuando ayuden. No asumas que conozco un concepto de Lua/Neovim de antemano.
- Priorizar simplicidad: preferir la forma "LazyVim" de hacer las cosas (extras
  oficiales, opts en vez de config custom) antes que soluciones a mano, salvo que
  yo pida explícitamente algo distinto.
- Testear cambios chicos (un plugin, un keymap) antes de tocar varios archivos
  a la vez.

### Estructura modular esperada
- `init.lua`: bootstrap, no debería tener casi nada custom.
- `lua/config/`: options, keymaps, autocmds, y el bootstrap de lazy.nvim.
- `lua/plugins/`: acá van MIS overrides y plugins extra — es la carpeta que LazyVim
  espera que el usuario use, un archivo por plugin o grupo temático.
- `lazy-lock.json`: versiones pineadas, se versiona en git, NO se edita a mano.
- Los plugins descargados viven en ~/.local/share/nvim/lazy/ — eso es caché
  generado, no es parte de este proyecto ni se edita ni se versiona.

### Engram
- El project es "nvim" (basename real de esta carpeta, NO inventar otro nombre).
  Guardá ahí el inventario inicial (versiones, qué está customizado vs stock
  LazyVim, qué falta instalar) y cada decisión de personalización que tomemos.

### CodeGraph
- No activo por ahora (cambios mínimos, config mayormente declarativa).
  Si el proyecto crece en complejidad, correr `codegraph init` acá y actualizar
  esta sección.
