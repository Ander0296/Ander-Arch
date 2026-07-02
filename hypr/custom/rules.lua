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
