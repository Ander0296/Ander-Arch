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

    -- LazyVim cierra el panel de dapui (consola incluida) apenas el
    -- programa termina ("dapui_config" en event_terminated/event_exited).
    -- Para programas rápidos sin breakpoint ni Scanner (como un Hello
    -- World) se cierra antes de que te dé tiempo a leer la salida.
    -- Cada vez que arranca una sesión (event_initialized), anulamos esos
    -- dos listeners: el panel queda abierto hasta que vos lo cierres a
    -- mano con <leader>du.
    dap.listeners.after.event_initialized["ander_keep_dapui_open"] = function()
      dap.listeners.before.event_terminated["dapui_config"] = nil
      dap.listeners.before.event_exited["dapui_config"] = nil
    end
  end,
})

-- FIX which-key + grug-far.
-- grug-far muestra su buffer (nvim_win_set_buf, grug-far.lua:299) ANTES de
-- crear sus keymaps \r, \s, \l... (farBuffer.lua:326). which-key escanea y
-- CACHEA los keymaps del buffer en el BufEnter de ese primer momento
-- (which-key/state.lua:143 -> buf.lua:183), así que se queda con un árbol
-- vacío y nunca registra "\" como trigger: por eso el "\" queda colgado en el
-- showcmd y el popup no aparece.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "grug-far",
  callback = function(ev)
    -- vim.schedule difiere esto al final del tick actual. Es imprescindible:
    -- el evento FileType se dispara DENTRO de setupBuffer, unas líneas antes
    -- de que se creen los keymaps. Sin el schedule, limpiaríamos el cache
    -- demasiado temprano y volveríamos a cachear vacío.
    vim.schedule(function()
      -- El buffer puede haberse cerrado en el intervalo (grug-far usa
      -- bufhidden=wipe en modo transient), así que validamos antes de tocarlo.
      if not vim.api.nvim_buf_is_valid(ev.buf) then
        return
      end
      -- Buf.clear invalida el cache de ese buffer para TODOS los modos. En el
      -- próximo BufEnter/cambio de modo which-key lo reconstruye, esta vez
      -- viendo los keymaps de grug-far, y registra "\" como trigger real.
      -- pcall porque which-key.buf es un módulo interno: si un update lo
      -- renombra, preferimos perder el popup antes que romper el autocmd.
      pcall(function()
        require("which-key.buf").clear({ buf = ev.buf })
      end)
    end)
  end,
})
