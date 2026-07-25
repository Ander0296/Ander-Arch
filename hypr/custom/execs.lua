hl.on("hyprland.start", function()
	hl.exec_cmd("1password") -- desbloqueo al inicio
	-- wallpaper automático: desactivado por defecto al iniciar, activalo con CTRL+SUPER+ALT+W
	hl.exec_cmd("bash ~/.config/hypr/scripts/start-wallpaperengine.sh") -- relanza el último wallpaper de Wallpaper Engine (no hace nada si esta PC no tiene el motor instalado)
end)
