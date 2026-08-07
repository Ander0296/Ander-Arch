-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "text", "markdown", "gitcommit", "plaintex", "typst" },
  callback = function()
    vim.opt_local.spell = false
    vim.opt_local.wrap = false
  end,
})

-- Java se indenta convencionalmente con 4 espacios, no los 2 que LazyVim
-- usa por default para el resto de los lenguajes. Como el formateo
-- automático al guardar usa este valor, arregla el problema de raíz.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "java",
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.expandtab = true
  end,
})

-- Al llegar a un breakpoint en un archivo que todavía no está abierto en
-- ninguna ventana (ej: entrar a GameHelper.java parado en SimpleStartupGame.java),
-- el default de nvim-dap no lo encuentra y tira "switchbuf setting prevented
-- jump to location" sin abrir nada. Se arregla en VeryLazy (evento que
-- LazyVim dispara una sola vez, apenas arranca nvim) para no tocar el
-- plugin spec de nvim-dap y no pisar la config que trae LazyVim.
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    local dap = require("dap")
    -- "usetab": si el archivo ya está abierto (en esta pestaña o en otra),
    -- salta ahí directo. "split": si es la primera vez que aparece (caso
    -- GameHelper), lo abre solo en un split nuevo. Nunca hace falta
    -- cerrar y volver a abrir nvim.
    dap.defaults.fallback.switchbuf = "usetab,split"
  end,
})
