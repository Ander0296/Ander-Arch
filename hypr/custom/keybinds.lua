-- ── Edit rápido de este archivo ─────────────────────────────────────────────
hl.bind(
	"CTRL+SUPER+ALT+Slash",
	hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"),
	{ description = "Edit user keybinds" }
) -- abre este archivo con el editor por defecto

-- Redefinido acá porque en hyprland/keybinds.lua está como `local` (no llega a este archivo)
local qsIsAlive = "qs -c $qsConfig ipc call TEST_ALIVE"

-- ── Sacar binds de upstream que chocan con hjkl / grupo Z / pantallazos / Tab ─
hl.unbind("SUPER + J") -- antes: Shell: Toggle bar
hl.unbind("SUPER + K") -- antes: Shell: Toggle on-screen keyboard
hl.unbind("SUPER + L") -- antes: Session: Lock
hl.unbind("SUPER + SHIFT + L") -- antes: Session: Sleep
hl.unbind("CTRL + SHIFT + ALT + SUPER + Delete") -- antes: Session: Shut down
hl.unbind("SUPER + SUPER_L") -- antes: abría el buscador al soltar Super + fallback fuzzel
hl.unbind("SUPER + SUPER_R") -- antes: lo mismo, con Super derecho

-- scratchpad Terminal
hl.bind(
	"SUPER + ALT + Return",
	hl.dsp.workspace.toggle_special("terminal"),
	{ description = "Utilities: Toggle terminal scratchpad" }
) -- muestra/oculta la terminal scratchpad (se crea sola la primera vez)

-- ── Reubicar lo que sacamos (bar toggle, teclado en pantalla) ───────────────
hl.bind("SUPER + ALT + J", hl.dsp.global("quickshell:barToggle"), { description = "Shell: Toggle bar" }) -- muestra/oculta la barra de Quickshell
hl.bind("SUPER + ALT + K", hl.dsp.global("quickshell:oskToggle"), { description = "Shell: Toggle on-screen keyboard" }) -- teclado en pantalla

-- ── Grupo de sesión / energía, todo bajo Z ─────────────────────────────────
hl.bind("SUPER + ALT + Z", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" }) -- bloquea la sesión
hl.bind(
	"SUPER + ALT + SHIFT + Z",
	hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"),
	{ locked = true, description = "Session: Sleep" }
) -- suspende el equipo
hl.bind(
	"SUPER + ALT + CTRL + Z",
	hl.dsp.exec_cmd("systemctl poweroff || loginctl poweroff"),
	{ description = "Session: Shut down" }
) -- apaga el equipo

-- ── Foco entre ventanas (hjkl) ──────────────────────────────────────────────
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }), { description = "Window: Focus Left (hjkl)" }) -- foco izquierda
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }), { description = "Window: Focus Right (hjkl)" }) -- foco derecha
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }), { description = "Window: Focus Up (hjkl)" }) -- foco arriba
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }), { description = "Window: Focus Down (hjkl)" }) -- foco abajo

-- ── Ciclar ventanas ─────────────────────────────────────────────────────────
hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { description = "Window: Cycle next" }) -- cicla entre todas las ventanas
hl.bind("ALT + Tab", hl.dsp.window.bring_to_top()) -- trae al frente la ventana ciclada

-- ── Redimensionar ventana (hjkl) ────────────────────────────────────────────
hl.bind(
	"SUPER + SHIFT + L",
	hl.dsp.window.resize({ x = 10, y = 0, relative = true }),
	{ repeating = true, description = "Window: Widen" }
)
hl.bind(
	"SUPER + SHIFT + H",
	hl.dsp.window.resize({ x = -10, y = 0, relative = true }),
	{ repeating = true, description = "Window: Narrow" }
)
hl.bind(
	"SUPER + SHIFT + K",
	hl.dsp.window.resize({ x = 0, y = -10, relative = true }),
	{ repeating = true, description = "Window: Shorten" }
)
hl.bind(
	"SUPER + SHIFT + J",
	hl.dsp.window.resize({ x = 0, y = 10, relative = true }),
	{ repeating = true, description = "Window: Heighten" }
)

-- ── Mover ventana entre tiles (hjkl) ─────────────────────────────────────────
hl.bind("SUPER + CTRL + H", hl.dsp.window.move({ direction = "l" }), { description = "Window: Move Left" }) -- mueve la ventana a la izquierda
hl.bind("SUPER + CTRL + L", hl.dsp.window.move({ direction = "r" }), { description = "Window: Move Right" }) -- mueve la ventana a la derecha
hl.bind("SUPER + CTRL + K", hl.dsp.window.move({ direction = "u" }), { description = "Window: Move Up" }) -- mueve la ventana arriba
hl.bind("SUPER + CTRL + J", hl.dsp.window.move({ direction = "d" }), { description = "Window: Move Down" }) -- mueve la ventana abajo

-- ── Capturas de pantalla ─────────────────────────────────────────────────────
-- ── Capturas de pantalla ─────────────────────────────────────────────────────
hl.unbind("Print") -- sacamos el default de upstream (grim+hyprctl, todo el monitor) para reemplazarlo por el snip de Quickshell

hl.bind("Print", hl.dsp.global("quickshell:regionScreenshot"), { description = "Utilities: Screen snip" }) -- mismo snip de Quickshell que SUPER+SHIFT+S; con savePath configurado, guarda y copia siempre
hl.bind(
	"Print",
	hl.dsp.exec_cmd(qsIsAlive .. " || pidof slurp || hyprshot --freeze --clipboard-only --mode region --silent")
) -- fallback si Quickshell no responde

-- ── Apps personales ──────────────────────────────────────────────────────────
hl.bind("SUPER + CTRL + ALT + A", hl.dsp.exec_cmd("anki"), { description = "App: Anki" }) -- abre Anki

-- ── Super solo: overlay de workspaces sin abrir el buscador ─────────────────
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel")) -- fallback si Quickshell no responde
hl.bind("SUPER + SUPER_R", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel")) -- ídem, con Super derecho

-- ── Overview general de workspaces, ahora en su propia tecla ────────────────
hl.bind(
	"SUPER + Space",
	hl.dsp.global("quickshell:overviewWorkspacesToggle"),
	{ description = "Shell: Toggle overview" }
) -- abre/cierra el overview de todos los workspaces

-- ── Ciclar layout del workspace actual (scrolling ↔ dwindle) ────────────────
hl.bind("SUPER + ALT + W", function()
	local layouts = { "scrolling", "dwindle" } -- los dos layouts entre los que alternamos
	local workspace = hl.get_active_special_workspace() or hl.get_active_workspace() -- toma el scratchpad si está abierto, si no el workspace normal
	if not workspace then
		return
	end

	local next_layout = "scrolling" -- valor por defecto si no se encuentra el actual en la lista
	for i = 1, #layouts do
		if layouts[i] == workspace.tiled_layout then
			next_layout = layouts[(i % #layouts) + 1] -- el siguiente de la lista, con vuelta al principio
			break
		end
	end

	if workspace.special then
		hl.workspace_rule({ workspace = tostring(workspace.name), layout = next_layout }) -- los scratchpads se identifican por nombre
	else
		hl.workspace_rule({ workspace = tostring(workspace.id), layout = next_layout }) -- los workspaces normales, por id
	end
end, { description = "Window: Cycle layout (scrolling/dwindle)" })

-- ── Acción distinta según el layout activo ──────────────────────────────────
local function layout_bind(bind_table)
	return function()
		local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
		if not workspace then
			return
		end
		local layout = workspace.tiled_layout
		if bind_table[layout] then
			hl.dispatch(bind_table[layout])
		end
	end
end

hl.bind(
	"SUPER + CTRL + ALT + H",
	layout_bind({
		scrolling = hl.dsp.layout("swapcol l"), -- columna activa va a la izquierda
	}),
	{ description = "Window: Swap column left / Cycle prev" }
)

hl.bind(
	"SUPER + CTRL + ALT + L",
	layout_bind({
		scrolling = hl.dsp.layout("swapcol r"), -- columna activa va a la derecha
	}),
	{ description = "Window: Swap column right / Cycle next" }
)
