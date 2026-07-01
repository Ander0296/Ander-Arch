hl.bind(
	"CTRL+SUPER+ALT+Slash",
	hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"),
	{ description = "Edit user keybinds" }
)
-- (línea existente, no la toques)
hl.bind(
	"CTRL+SUPER+ALT+Slash",
	hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"),
	{ description = "Edit user keybinds" }
)

-- ── Sacar los binds de upstream que chocan con hjkl / el nuevo grupo Z ────────
hl.unbind("SUPER + J") -- antes: Shell: Toggle bar
hl.unbind("SUPER + K") -- antes: Shell: Toggle on-screen keyboard
hl.unbind("SUPER + L") -- antes: Session: Lock
hl.unbind("SUPER + SHIFT + L") -- antes: Session: Sleep
hl.unbind("CTRL + SHIFT + ALT + SUPER + Delete") -- antes: Session: Shut down

-- ── Reubicar lo que sacamos ────────────────────────────────────────────────
hl.bind("SUPER + ALT + J", hl.dsp.global("quickshell:barToggle"), { description = "Shell: Toggle bar" })
hl.bind("SUPER + ALT + K", hl.dsp.global("quickshell:oskToggle"), { description = "Shell: Toggle on-screen keyboard" })

-- ── Grupo de sesión / energía, todo bajo Z ─────────────────────────────────
hl.bind("SUPER + ALT + Z", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind(
	"SUPER + ALT + SHIFT + Z",
	hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"),
	{ locked = true, description = "Session: Sleep" }
)
hl.bind(
	"SUPER + ALT + CTRL + Z",
	hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"),
	{ description = "Session: Shut down" }
)

-- ── Foco entre ventanas (hjkl) ──────────────────────────────────────────────
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }), { description = "Window: Focus Left (hjkl)" })
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }), { description = "Window: Focus Right (hjkl)" })
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }), { description = "Window: Focus Up (hjkl)" })
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }), { description = "Window: Focus Down (hjkl)" })

-- ── Ciclar ventanas ─────────────────────────────────────────────────────────
hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { description = "Window: Cycle next" })
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top()) -- trae la ventana ciclada al frente

-- ── Redimensionar ventana (hjkl) ────────────────────────────────────────────
hl.bind(
	"SUPER + SHIFT + L",
	hl.dsp.window.resize({ x = 10, y = 0 }),
	{ repeating = true, description = "Window: Widen" }
)
hl.bind(
	"SUPER + SHIFT + H",
	hl.dsp.window.resize({ x = -10, y = 0 }),
	{ repeating = true, description = "Window: Narrow" }
)
hl.bind(
	"SUPER + SHIFT + K",
	hl.dsp.window.resize({ x = 0, y = -10 }),
	{ repeating = true, description = "Window: Shorten" }
)
hl.bind(
	"SUPER + SHIFT + J",
	hl.dsp.window.resize({ x = 0, y = 10 }),
	{ repeating = true, description = "Window: Heighten" }
)

-- ── Mover ventana entre tiles (hjkl) ─────────────────────────────────────────
hl.bind("SUPER + CTRL + H", hl.dsp.window.move({ direction = "l" }), { description = "Window: Move Left" })
hl.bind("SUPER + CTRL + L", hl.dsp.window.move({ direction = "r" }), { description = "Window: Move Right" })
hl.bind("SUPER + CTRL + K", hl.dsp.window.move({ direction = "u" }), { description = "Window: Move Up" })
hl.bind("SUPER + CTRL + J", hl.dsp.window.move({ direction = "d" }), { description = "Window: Move Down" })
