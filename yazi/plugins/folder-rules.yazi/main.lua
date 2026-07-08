local function setup()
	ps.sub("ind-sort", function(opt)
		local cwd = cx.active.current.cwd
		if cwd:ends_with("Downloads") then
			-- En Downloads: más reciente primero (para encontrar lo que acabás de bajar)
			opt.by, opt.reverse, opt.dir_first = "mtime", true, false
		else
			-- En cualquier otra carpeta: tu orden global de yazi.toml
			opt.by, opt.reverse, opt.dir_first = "natural", false, true
		end
		return opt
	end)
end

return { setup = setup }
