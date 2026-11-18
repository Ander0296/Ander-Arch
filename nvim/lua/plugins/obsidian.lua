return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- latest release
  ft = "markdown", -- load only when opening markdown files
  keys = {
    { "<leader>so", "<cmd>Obsidian quick_switch<cr>", desc = "Obsidian notes (incl. missing)" },
  },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false, -- use ":Obsidian <command>" syntax only
    workspaces = {
      { name = "cabletronics", path = "~/Proyectos/Cabletronics" },
      { name = "cerebro", path = "~/Proyectos/Cerebro" },
    },
    -- File name = note title, same as Obsidian does
    note_id_func = function(title)
      return title or tostring(os.time())
    end,
    -- Do not inject id/aliases/tags properties into notes
    frontmatter = { enabled = false },
    -- Index notes and links so pickers can list links to missing notes
    cache = { enabled = true },
    quick_switch = { show_existing_only = false },
  },
}
