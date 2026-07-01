return {
  {
    "xiyaowong/transparent.nvim",      -- plugin para fondo transparente
    lazy = false,                      -- cargar siempre, no lazy
    config = function()
      vim.g.transparent_enabled = true -- activar transparencia por defecto siempre
      require("transparent").setup({
        extra_groups = {               -- grupos adicionales a hacer transparentes
          "NormalFloat",               -- ventanas flotantes
          "NvimTreeNormal",            -- árbol de archivos
          "TelescopeNormal",           -- ventana de telescope
          "TelescopeBorder",           -- borde de telescope
        },
      })
      require("transparent").clear_prefix("BufferLine") -- tabs transparentes
    end,
  },
}
