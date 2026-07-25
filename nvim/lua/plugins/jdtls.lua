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
    return opts
  end,
}
