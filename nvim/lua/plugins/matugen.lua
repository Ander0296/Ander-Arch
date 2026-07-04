return {
  {
    "daedlock/matugen.nvim",
    lazy = false, -- es un colorscheme, tiene que cargar de entrada, no bajo demanda
    priority = 1000, -- antes que el resto de los plugins de UI (mismo criterio que cualquier colorscheme)
    config = function()
      require("matugen").setup({
        -- el mismo JSON que ya generamos con matugen en cada cambio de wallpaper,
        -- registrado como [templates.m3colors] en ~/.config/matugen/config.toml
        colors_path = "~/.local/state/quickshell/user/generated/colors.json",
      })
      vim.cmd.colorscheme("matugen") -- lo activa como colorscheme real
    end,
  },
  -- le decimos a LazyVim que el colorscheme activo es "matugen", para que no
  -- pelee tratando de volver a tokyonight al arrancar
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "matugen",
    },
  },
}
