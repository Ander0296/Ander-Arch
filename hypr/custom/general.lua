hl.config({
	general = { layout = "scrolling" },
	scrolling = {
		fullscreen_on_one_column = true,
		column_width = 1.0,
		wrap_swapcol = false,
	},
	input = {
		kb_layout = "us",
		kb_variant = "dvorak-alt-intl", -- variante dvorak con teclas internacionales en AltGr
		numlock_by_default = true,
		repeat_rate = 50, -- repeticiones por segundo al sostener una tecla
		repeat_delay = 300, -- ms antes de que empiece la repetición
		focus_on_close = 2, -- al cerrar ventana, foco va a la más recientemente usada
		touchpad = {
			natural_scroll = false, -- scroll tradicional
			clickfinger_behavior = true, -- 1/2/3 dedos = clic izq/der/medio
			scroll_factor = 0.3, -- scroll más lento con dos dedos
		},
	},

	decoration = {
		blur = {
			enabled = false, -- apagado total del blur, para la prueba
			xray = false,
		},
	},
})

hl.workspace_rule({
	workspace = "special:terminal", -- workspace especial para el scratchpad
	on_created_empty = "[float; size 900 550; center] kitty --app-id scratch_term", -- abre kitty flotante y centrada cuando está vacío
	persistent = false, -- se destruye cuando cerrás la terminal, así la próxima vez spawnea de nuevo
})
