return {
  "mfussenegger/nvim-jdtls",
  opts = function(_, opts)
    -- LazyVim agrega el javaagent de Lombok por defecto; acá no se usa
    -- Lombok y un javaagent instrumenta cada clase al cargar, frenando
    -- el arranque de jdtls.
    opts.cmd = vim.tbl_filter(function(arg)
      return not arg:find("lombok", 1, true)
    end, opts.cmd)
    -- Flags de arranque de la JVM: JIT menos agresivo al inicio y GC
    -- paralelo (el que mejor arranca con heaps chicos).
    vim.list_extend(opts.cmd, {
      "--jvm-arg=-XX:+UseParallelGC",
      "--jvm-arg=-XX:TieredStopAtLevel=1",
    })

    -- jdtls arma la lista de clases con "main" (la que ves en el picker
    -- "Configuration") una única vez al arrancar. Una clase creada
    -- después (como Pruebas.java) no entra ahí hasta reiniciar nvim.
    -- Repetimos ese descubrimiento cada vez que guardás un .java, así
    -- <leader>dc siempre ve las clases nuevas sin reiniciar nada.
    vim.api.nvim_create_autocmd("BufWritePost", {
      pattern = "*.java",
      callback = function()
        if #vim.lsp.get_clients({ name = "jdtls" }) > 0 then
          require("jdtls.dap").setup_dap_main_class_configs()
        end
      end,
    })

    return opts
  end,
}
