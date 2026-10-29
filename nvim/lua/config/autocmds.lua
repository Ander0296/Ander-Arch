-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Borra el autocmd de LazyVim que, en archivos de texto (text, markdown,
-- gitcommit...), partía las líneas largas (wrap) y prendía la ortografía en
-- inglés (spell), que subraya todo lo escrito en español.
-- Para un buffer puntual se vuelven a prender con <leader>uw (wrap) y <leader>us (spell).
vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
