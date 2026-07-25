return {
  "saghen/blink.cmp",
  opts = {
    keymap = {
      -- false = "blink, no toques esta tecla". Enter vuelve a ser Enter
      -- normal (salto de línea) y JAMÁS acepta un completado, sin importar
      -- si el menú está abierto o no.
      ["<CR>"] = false,
    },
  },
}
