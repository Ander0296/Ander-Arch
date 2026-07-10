local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Extras oficiales de LazyVim. Van acá, DESPUÉS de lazyvim.plugins y
    -- ANTES de tus propios plugins, porque LazyVim valida ese orden exacto
    -- (lazyvim/config/init.lua:221) y tira warning si no lo respetás.
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.python" },
    -- NUEVO: soporte Java. Instala jdtls (el mismo motor LSP que usa Eclipse),
    -- más java-debug-adapter y java-test para debug/testing.
    { import = "lazyvim.plugins.extras.lang.java" },
    -- NUEVO: debugger genérico (nvim-dap + panel visual nvim-dap-ui).
    -- Sin esto, jdtls no tiene con qué "correr" el main(): esta extra agrega
    -- el keymap <leader>dc (Run/Continue) y el panel <leader>du.
    { import = "lazyvim.plugins.extras.dap.core" },
    -- NUEVO: asistente de IA (avante.nvim). El provider por default es
    -- "copilot"; lo pisamos a Gemini en lua/plugins/ai.lua.
    { import = "lazyvim.plugins.extras.ai.avante" },
    { import = "lazyvim.plugins.extras.ai.claudecode" },
    -- import/override with your plugins
    -- NUEVO: surround (envolver/cambiar/borrar paréntesis, comillas, tags).
    -- LazyVim remapea sus teclas por default (sa/sd/sr) al prefijo "gs"
    -- para no chocar con flash.nvim, que ya usa "s"/"S" para saltar.
    { import = "lazyvim.plugins.extras.coding.mini-surround" },
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- notify on update
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
