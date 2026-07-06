return {
  "mikavilpas/yazi.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = {
    { "nvim-lua/plenary.nvim", lazy = true },
  },
  keys = {
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
