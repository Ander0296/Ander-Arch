return {
  {
    "yetone/avante.nvim",
    -- Desactivado: nos quedamos con claudecode.nvim (Claude Code real) en vez
    -- de avante. "enabled = false" apaga el plugin entero -- ya no carga sus
    -- comandos ni sus atajos, así que <leader>aa/ac/af/ar/as quedan libres
    -- para ClaudeCode sin pelea.
    enabled = false,
  },
  {
    "coder/claudecode.nvim",
    opts = {
      terminal = {
        -- snacks_win_opts pisa la geometría de la ventana. position = "float"
        -- la saca del split y la centra como popup, en vez de pegada a un borde.
        snacks_win_opts = {
          position = "float",
          width = 0.85, -- 85% del ancho de la pantalla -- bien grande
          border = "rounded",
          keys = {
            -- Ctrl+, ADENTRO de la terminal (modo terminal) la esconde.
            -- No toca Ctrl+C a propósito: ese sigue yendo derecho al proceso
            -- `claude`, que es como se interrumpe una respuesta larga.
            claude_hide = {
              "<C-,>",
              function(self)
                self:hide()
              end,
              mode = "t",
              desc = "Esconder Claude",
            },
          },
        },
      },
    },
    -- Sumamos <leader>am para elegir modelo (opus/sonnet/haiku) sin escribir
    -- el comando entero. NO copiamos <leader>at/<leader>av de la config de
    -- referencia porque apuntan a comandos que no existen en esta versión
    -- del plugin (verificado: cero resultados al buscarlos en el código
    -- fuente instalado) -- son cruft de una versión vieja.
    keys = {
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Elegir modelo Claude" },
      -- Ctrl+, FUERA de la terminal (normal/visual) la abre/togglea. Mismo
      -- físico combo que arriba, distinta acción según el modo en el que
      -- estás -- por eso desde cualquier lado es una sola tecla para
      -- abrir y cerrar. <leader>ac sigue funcionando igual, por si la
      -- preferís también.
      { "<C-,>", "<cmd>ClaudeCode<cr>", desc = "Abrir/cerrar Claude", mode = { "n", "x" } },
    },
  },
}
