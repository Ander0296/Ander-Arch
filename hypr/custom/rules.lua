hl.window_rule({
	match = { class = "kitty" },
	opacity = "1 1", -- ya no necesita opacidad de Hyprland, la maneja kitty
	no_blur = false, -- esto sí lo dejamos, para que el blur siga activo
})

hl.window_rule({
	match = { class = "org.kde.dolphin" },
	opacity = "0.9 0.75",
	no_blur = false,
})

-- Popup flotante para "m e" en yazi (explicación de archivo con Claude Code):
-- se identifica por su --class propio, no toca ninguna ventana kitty normal
hl.window_rule({ match = { class = "ai-explain-popup" }, float = true })
hl.window_rule({ match = { class = "ai-explain-popup" }, center = true })
hl.window_rule({ match = { class = "ai-explain-popup" }, size = { "(monitor_w*0.5)", "(monitor_h*0.5)" } })

-- ttyper ahora es un scratchpad (special:typing en custom/general.lua);
-- float/center/size ya los define el on_created_empty de ese workspace_rule

-- Packet Tracer (XWayland, Qt propio): con un diálogo modal abierto (Preferences),
-- al sacar el mouse el foco pasa a otra ventana, Qt pide "activar" el diálogo de nuevo
-- y focus_on_activate lo enfoca y devuelve el cursor al centro. Se ignoran esos pedidos.
hl.window_rule({ match = { class = "PacketTracer" }, suppress_event = "activate activatefocus" })
