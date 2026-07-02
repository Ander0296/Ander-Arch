hl.on("hyprland.start", function()
	hl.exec_cmd("1password") -- desbloqueo al inicio
	hl.exec_cmd("bash ~/.config/hypr/scripts/random-wallpaper-loop.sh") -- cambia el wallpaper cada 1 hora
end)
