hl.on("hyprland.start", function()
	hl.exec_cmd("1password") -- desbloqueo al inicio
	-- wallpaper automático: desactivado por defecto al iniciar, activalo con CTRL+SUPER+ALT+W
	-- Wallpaper Engine: arranca la GUI oculta en su scratchpad; ella sola
	-- restaura el último wallpaper/monitor (tiene su propio watchdog).
	-- Si el binario no existe en esta PC, Hyprland simplemente no abre nada,
	-- igual que con cualquier otro exec de una app no instalada.
	hl.exec_cmd("[workspace special:wallpaperengine silent; float; size 1200 700; center] wallpaperengine-gui")
end)
