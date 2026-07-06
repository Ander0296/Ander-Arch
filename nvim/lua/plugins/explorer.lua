return {
  {
    "folke/snacks.nvim",
    opts = {
      -- LazyVim reemplaza netrw (el explorador nativo de Vim) con el panel
      -- de snacks automáticamente cada vez que se abre una carpeta como si
      -- fuera un archivo. Como solo usamos yazi como explorer, apagamos
      -- ese reemplazo automático para que no vuelva a aparecer solo.
      explorer = { replace_netrw = false },
    },
  },
}
