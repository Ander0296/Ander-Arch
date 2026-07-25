return {
  -- Repo del plugin en GitHub
  "MeanderingProgrammer/render-markdown.nvim",

  -- Solo se carga cuando abrís un archivo .md (lazy-loading: no pesa en el arranque)
  ft = { "markdown" },

  -- Dependencias que necesita para funcionar
  dependencies = {
    "nvim-treesitter/nvim-treesitter", -- parsea la sintaxis de markdown para saber qué renderizar
    "nvim-tree/nvim-web-devicons", -- iconos (para bullets, íconos de archivo en links, etc.)
  },

  -- Configuración: se ejecuta cuando el plugin carga
  opts = {},
}
