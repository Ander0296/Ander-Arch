return {
  "mikavilpas/yazi.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = {
    { "nvim-lua/plenary.nvim", lazy = true },
  },
  keys = {
    {
      "<leader>-",
      mode = { "n", "v" },
      "<cmd>Yazi<cr>",
      desc = "Abrir yazi en el archivo actual",
    },
    {
      "<c-up>",
      "<cmd>Yazi toggle<cr>",
      desc = "Reanudar la última sesión de yazi",
    },
  },
  opts = {
    keymaps = { show_help = "<f1>" },
  },
}
