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

-- LazyVim trae por default <leader>uz = zen y <leader>uZ = zoom. Acá los
-- intercambiamos: "map" vuelve a bindear la tecla nueva sobre el mismo
-- toggle, así que basta con llamarlo de nuevo con el leader cambiado
-- (el bind viejo queda pisado porque set_keymap con el mismo lhs reemplaza).
Snacks.toggle.zoom():map("<leader>uz")
Snacks.toggle.zen():map("<leader>uZ")

-- Guarda la carpeta del último archivo real (no de la terminal) para que
-- el toggle de <C-/> sepa qué terminal cerrar cuando lo apretás desde ADENTRO.
local java_term_dir = nil

local function toggle_term_here()
  -- Si NO estás parado en la terminal (buftype != "terminal"), estás en un
  -- archivo real: recalculá la carpeta a partir de ese archivo.
  if vim.bo.buftype ~= "terminal" then
    java_term_dir = vim.fn.expand("%:p:h") -- %:p:h = ruta absoluta de la carpeta del buffer actual
  end
  -- Si SÍ estás en la terminal, java_term_dir queda con el valor de la
  -- última vez, así el id (cmd+cwd) coincide y focus() la esconde en vez
  -- de crear una nueva.
  Snacks.terminal.focus(nil, { cwd = java_term_dir })
end

-- Pisa el bind default de LazyVim (que usaba LazyVim.root()) con el nuestro.
-- <C-_> queda afuera a propósito: en kitty ese combo ya está tomado por
-- "change_font_size all -1" (~/.config/kitty/*.conf), nunca llega a nvim.
vim.keymap.set({ "n", "t" }, "<C-/>", toggle_term_here, { desc = "Terminal (carpeta del archivo)" })
