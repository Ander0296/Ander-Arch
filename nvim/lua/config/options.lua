-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.spell = false
vim.opt.wrap = false
-- vim.opt.mouse = "" -- Desactivar el mouse
vim.opt.scrolloff = 999 -- Mantener foco en el centro

-- Sin esto, :terminal (y Snacks.terminal) usan $SHELL, que para este user
-- es bash -- distinto de la shell real (fish, con starship e íconos) que
-- abre kitty en Hyprland. Esto hace que la terminal de nvim use la MISMA
-- shell que tu terminal normal.
vim.o.shell = "/usr/bin/fish"
