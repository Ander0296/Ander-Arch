return {
  -- El escaneo de clases con main() solo corre cuando jdtls se conecta al
  -- buffer; una clase creada después no aparece en el picker de debug hasta
  -- re-ejecutarlo. Este keymap lo refresca sin reiniciar nvim.
  {
    "mfussenegger/nvim-jdtls",
    keys = {
      {
        "<leader>dj",
        function()
          -- verbose avisa que arrancó y on_ready cuando terminó: el escaneo
          -- es asíncrono y sin aviso parece que la tecla no hizo nada.
          require("jdtls.dap").setup_dap_main_class_configs({
            verbose = true,
            on_ready = function()
              vim.notify("Java debug configs updated")
            end,
          })
        end,
        desc = "Refresh Java debug configs",
        ft = "java",
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    keys = {
      {
        "<leader>dc",
        function()
          -- Guardar todo antes de correr/continuar: debugear con cambios
          -- sin guardar desincroniza las líneas del compilado y el buffer
          -- (warning "Adapter reported frame ... Invalid cursor line").
          vim.cmd("silent! wall")
          require("dap").continue()
        end,
        desc = "Run/Continue",
      },
    },
    opts = function()
      -- La extra de Java de LazyVim registra "Debug (Attach) - Remote"
      -- (conexión a una JVM remota en el puerto 5005). Acá no se debuggean
      -- JVMs remotas, y elegirla por error termina en "Failed to attach";
      -- se vacía la lista para que queden solo las main classes que
      -- agrega jdtls al attachear.
      local dap = require("dap")
      dap.configurations.java = {}
      -- Al pausar, saltar SIEMPRE a la ventana que ya muestra el archivo.
      -- El default ("uselast") usa la última ventana activa, y si el foco
      -- venía de un panel de dapui intenta poner la línea ahí y tira
      -- "Adapter reported frame ... Invalid cursor line".
      dap.defaults.fallback.switchbuf = "useopen"
    end,
  },

  {
    "rcarriga/nvim-dap-ui",
    opts = {
      -- Layout propio (idea tomada de bcampolo/nvim-starter-kit): scopes
      -- ocupa la mitad del panel izquierdo porque es lo que más se mira
      -- (valores de variables); repl + console van abajo.
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.50 },
            { id = "stacks", size = 0.30 },
            { id = "watches", size = 0.10 },
            { id = "breakpoints", size = 0.10 },
          },
          size = 40,
          position = "left",
        },
        {
          elements = { "repl", "console" },
          size = 10,
          position = "bottom",
        },
      },
    },
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
