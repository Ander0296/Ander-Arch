return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    -- símbolo de Arch Linux (nf-dev-archlinux, U+E732) delante del nombre
    -- del archivo cuando hay cambios sin guardar; LazyVim lo deja vacío
    -- por defecto y solo cambia el color (ver util/lualine.lua pretty_path)
    opts.sections.lualine_c[#opts.sections.lualine_c] = {
      LazyVim.lualine.pretty_path({ modified_sign = " \u{e732}" }),
    }
    return opts
  end,
}
