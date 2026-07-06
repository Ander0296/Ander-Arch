return {
  {
    "rcarriga/nvim-dap-ui",
    opts = {},
    config = function(_, opts)
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      -- Igual que el default de LazyVim: abrir el panel cuando arranca la
      -- sesión de debug/run.
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      -- A diferencia del default de LazyVim, ACÁ NO agregamos los listeners
      -- que cierran el panel solo cuando el programa termina o corta la
      -- sesión — por eso se queda abierto y podés leer la salida.

      -- Bug de compatibilidad entre nvim-dap y esta versión de Neovim: al
      -- abrir una terminal integrada (necesaria para programas que leen
      -- System.in, como Scanner), el buffer que crea queda "modified" y
      -- Neovim rechaza abrir ahí una terminal. Forzamos modified=false
      -- justo antes de que arranque.
      dap.defaults.fallback.terminal_win_cmd = function()
        vim.cmd("belowright new")
        local buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].modified = false
        return buf, vim.api.nvim_get_current_win()
      end
    end,
  },
}
