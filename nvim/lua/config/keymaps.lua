-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Reusa los atajos que antes abrían el explorer de snacks para que ahora
-- abran yazi (mismo comando que ya usa yazi.lua en <leader>-).
vim.keymap.set("n", "<leader>e", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
vim.keymap.set("n", "<leader>E", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
vim.keymap.set("n", "<leader>fe", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })
vim.keymap.set("n", "<leader>fE", "<cmd>Yazi<cr>", { desc = "Explorer (yazi)" })

-- Corre "mvn test" en una terminal flotante, ubicando automáticamente la
-- raíz del proyecto Maven actual (busca hacia arriba desde el buffer
-- abierto hasta encontrar un pom.xml — así funciona en CUALQUIER ejercicio,
-- no solo en ejercicio-suma).
vim.keymap.set("n", "<leader>tm", function()
  -- vim.fs.root(0, "pom.xml"): función nativa de Neovim (0.10+). El "0" es
  -- el buffer actual; busca "pom.xml" en esa carpeta y, si no está, sube un
  -- nivel y repite, hasta encontrarlo o llegar a la raíz del disco.
  local root = vim.fs.root(0, "pom.xml")
  if not root then
    -- Si abriste un archivo que no está dentro de ningún proyecto Maven,
    -- avisamos en vez de fallar en silencio.
    vim.notify("No se encontró pom.xml en ningún directorio padre", vim.log.levels.WARN)
    return
  end
  -- auto_close = false: sin esto, la terminal se cierra sola apenas termina
  -- el comando (incluso si "mvn test" salió bien) — no te da tiempo a leer
  -- el resultado. Con false, se queda abierta hasta que la cierres vos con
  -- "q" (ya viene mapeado por default en toda terminal de snacks).
  Snacks.terminal("mvn test", { cwd = root, auto_close = false })
end, { desc = "Maven: correr tests (mvn test)" })
