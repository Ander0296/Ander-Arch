-- Tema de nvim: tokyonight (el que trae LazyVim), con fondo transparente
-- para que se vea la transparencia de kitty (background_opacity en kitty/kitty.conf).
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true, -- sin color de fondo en el editor: se ve lo que hay detrás de kitty
      styles = {
        sidebars = "transparent", -- paneles laterales (explorador de archivos, etc.) también transparentes
        floats = "transparent", -- ventanas flotantes (ayuda, which-key, diagnósticos) también transparentes
      },
    },
  },
}
