return {
  {
    "yetone/avante.nvim",
    opts = {
      provider = "gemini",
      providers = {
        gemini = {
          -- Modelo principal: el de más cupo diario (500 por día).
          model = "gemini-3.1-flash-lite",
        },
      },
    },
    keys = {
      {
        "<leader>ag",
        function()
          -- Lista de modelos para rotar, del que más cupo tiene al que menos.
          local models = { "gemini-3.1-flash-lite", "gemini-2.5-flash", "gemini-3-flash" }
          local config = require("avante.config")
          local current = config.providers.gemini.model
          -- Busca dónde está el modelo actual en la lista y pasa al siguiente
          -- (si estaba en el último, vuelve al primero).
          local idx = 1
          for i, m in ipairs(models) do
            if m == current then
              idx = i
            end
          end
          local next_model = models[(idx % #models) + 1]
          config.override({ providers = { gemini = { model = next_model } } })
          vim.notify("Avante/Gemini: cambiado a " .. next_model, vim.log.levels.INFO)
        end,
        desc = "Rotar modelo Gemini (3.1 Flash Lite -> 2.5 Flash -> 3 Flash)",
      },
    },
  },
}
