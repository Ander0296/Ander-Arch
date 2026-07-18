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

-- Popup flotante para practicar mecanografía con ttyper
hl.window_rule({ match = { class = "typing-practice" }, float = true })
hl.window_rule({ match = { class = "typing-practice" }, center = true })
hl.window_rule({ match = { class = "typing-practice" }, size = { "(monitor_w*0.6)", "(monitor_h*0.6)" } })
