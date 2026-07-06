-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Reusa los atajos que antes abrían el explorer de snacks para que ahora
-- abran yazi (mismo comando que ya usa yazi.lua en <leader>-).
vim.keymap.set("n", "<leader>e", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
vim.keymap.set("n", "<leader>E", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
-- Mismo criterio que <leader>e/E: pisamos también fe/fE para que TODOS los
-- atajos de "explorer" abran yazi, sin dejar ningún resto de snacks_explorer.
vim.keymap.set("n", "<leader>fe", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
vim.keymap.set("n", "<leader>fE", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
