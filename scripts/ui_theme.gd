class_name UITheme
extends RefCounted
## Shared visual language for the 2026-09-10 redesign (reference: a 4-screen
## mobile UI mockup the user provided, matched for "99% likeness" on the
## VISUAL side only -- mechanics are unchanged, see project memory on that
## decision). Every top-level screen should build its chrome through this
## file instead of re-deriving its own palette/fonts/shapes, the same
## "shared by convention" pattern TeamColor/UnitDatabase already use, except
## this time actually centralized in one file instead of copy-pasted consts
## per screen (a recurring bit of drift all last redesign pass).

const BG := Color(0.02, 0.03, 0.06)
const CARD_BG := Color(0.07, 0.07, 0.13)
const CYAN := Color(0.3, 0.85, 1.0)
const VIOLET := Color(0.65, 0.45, 0.95)
const TEXT_BRIGHT := Color(0.95, 0.96, 1.0)
const TEXT_MUTED := Color(0.55, 0.58, 0.7)
const HEX_INNER := Color(0.12, 0.11, 0.22)

const HEADER_FONT := preload("res://assets/fonts/Orbitron.ttf")
const BODY_FONT := preload("res://assets/fonts/Rajdhani-Regular.ttf")
const BODY_FONT_SEMIBOLD := preload("res://assets/fonts/Rajdhani-SemiBold.ttf")

const NEON_PANEL_SHADER := preload("res://shaders/neon_panel.gdshader")
const PANEL_TILE_TEXTURE := preload("res://assets/ui/panel_tile.png")
## Source is 260x164 (downscaled from the raw 865x547 Meshy generation --
## NinePatchRect margins are in TEXTURE pixels and render at that exact
## on-screen size regardless of the destination rect, so the original
## resolution's ~110px border/corner-bracket region would have overwhelmed
## anything shorter than ~220px, like the 70px Settings buttons). This
## margin covers the border + corner brackets so only the flat glass fill
## in the middle ever stretches.
const PANEL_TILE_MARGIN := 33
const PANEL_HUE_SHIFT_SHADER := preload("res://shaders/panel_hue_shift.gdshader")


## Real painted panel art (2026-09-10, Meshy-generated) used as a stretchable
## NinePatchRect instead of the procedural gradient-shader panel -- replaces
## build_gradient_panel() wherever a screen wants the richer painted-glass
## look (Home screen tiles/banner, Settings buttons) rather than the flatter
## vector gradient. build_gradient_panel() is kept for cases that need a
## specific accent color pair per instance (e.g. per-unit-type borders on
## Draft/Heroes cards) since this single texture's cyan-violet gradient is
## baked in and can't be recolored per call the way the shader can.
##
## The border gradient also animates -- a slow continuous hue rotation
## (shaders/panel_hue_shift.gdshader) keeps it "dynamically gradienting"
## per explicit request, rather than sitting on the single static cyan-
## violet bake from the source art.
static func build_painted_panel(size: Vector2) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.texture = PANEL_TILE_TEXTURE
	panel.size = size
	panel.patch_margin_left = PANEL_TILE_MARGIN
	panel.patch_margin_right = PANEL_TILE_MARGIN
	panel.patch_margin_top = PANEL_TILE_MARGIN
	panel.patch_margin_bottom = PANEL_TILE_MARGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PANEL_HUE_SHIFT_SHADER
	panel.material = mat
	return panel


## A glowing gradient-bordered panel (see neon_panel.gdshader) -- the card
## frame + button-fill look throughout the reference mockup, not achievable
## with a plain StyleBoxFlat (solid colors only, no gradients).
static func build_gradient_panel(size: Vector2, radius: float = 18.0, border_width: float = 2.5,
		filled: bool = false, color_a: Color = CYAN, color_b: Color = VIOLET, glow: float = 1.0) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = NEON_PANEL_SHADER
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("border_width", border_width)
	mat.set_shader_parameter("filled", filled)
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	mat.set_shader_parameter("glow_strength", glow)
	rect.material = mat
	return rect


## Gradient-fill CTA button (the "GET STARTED" / "SAVE DECK" look) -- a
## gradient panel used as the button's own visual with a transparent Button
## layered on top for input, since Button's theme overrides can't do
## gradients either.
static func build_gradient_button(text: String, size: Vector2) -> Dictionary:
	var container := Control.new()
	container.size = size

	var bg := build_gradient_panel(size, size.y * 0.32, 0.0, true, CYAN, VIOLET, 0.6)
	container.add_child(bg)

	var label := Label.new()
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", BODY_FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	var button := Button.new()
	button.size = size
	button.flat = true
	button.modulate.a = 0.0  # invisible, purely for input + hover/press signal
	container.add_child(button)

	return {"container": container, "button": button}


## Procedural hexagon badge (same "shape built in code, no new art" approach
## as _build_star()/_build_heart() in match_controller.gd) -- the numeric
## cost/level indicators in the reference are hexagons, not the rounded
## squares this project used before.
static func build_hex_badge(value: String, size: float = 24.0) -> Control:
	var container := Control.new()
	container.size = Vector2(size, size) * 2.0
	container.pivot_offset = container.size * 0.5

	var center := container.size * 0.5

	var outer := Polygon2D.new()
	var outer_pts := PackedVector2Array()
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 90.0)
		outer_pts.append(center + Vector2(cos(angle), sin(angle)) * size)
	outer.polygon = outer_pts
	outer.color = HEX_INNER
	container.add_child(outer)

	var outer_line := Line2D.new()
	outer_line.width = 2.0
	outer_line.default_color = CYAN
	outer_line.closed = true
	for p in outer_pts:
		outer_line.add_point(p)
	container.add_child(outer_line)

	var inner_line := Line2D.new()
	inner_line.width = 1.5
	inner_line.default_color = VIOLET
	inner_line.closed = true
	for i in 6:
		var angle := deg_to_rad(60.0 * i - 90.0)
		inner_line.add_point(center + Vector2(cos(angle), sin(angle)) * (size - 5.0))
	container.add_child(inner_line)

	var label := Label.new()
	label.size = container.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HEADER_FONT)
	label.add_theme_font_size_override("font_size", int(size * 0.62))
	label.add_theme_color_override("font_color", TEXT_BRIGHT)
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(label)

	return container


## Small procedural diamond/gem icon (currency badges) -- a shape, not a
## Unicode glyph (e.g. "◆"), since glyph coverage for less-common symbols
## varies by device font and risks rendering as a tofu box on some phones.
static func build_diamond(size: float, color: Color) -> Polygon2D:
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -size), Vector2(size * 0.75, 0), Vector2(0, size), Vector2(-size * 0.75, 0),
	])
	diamond.color = color
	return diamond


## Icon set (2026-09-10) -- Meshy-generated glowing line-art icons
## (assets/icons/icon_*.png, sliced from a single 6-icon reference sheet),
## replacing an earlier procedural Line2D version that read as thin/amateur
## next to the reference mockup's icon work. Each source PNG is a WHITE
## shape with the glow's own soft falloff baked into the alpha channel
## (RGB=255,255,255, alpha=brightness) rather than a fixed baked-in color --
## `modulate` then recolors it to any accent (cyan, violet, muted grey)
## cleanly, the same trick TeamColor uses for grayscale rim-light art.
static func _icon_texture(name: String, size: float, color: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/icons/icon_%s.png" % name)
	# expand_mode/stretch_mode MUST be set before `.size` below: a bare
	# Control (no Container parent) still clamps size up to its combined
	# minimum size at assignment time, and with a texture already assigned,
	# the still-default EXPAND_KEEP_SIZE reports that minimum as the
	# texture's own native size (256x256 for these icons) -- so setting
	# `.size` first got silently clamped back up to 256x256 regardless of
	# what expand_mode was set to afterward (confirmed by printing
	# t.size post-assignment). EXPAND_IGNORE_SIZE first makes the minimum
	# (0, 0), so the explicit size below actually sticks.
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func build_icon_home(size: float, color: Color) -> Control:
	return _icon_texture("home", size, color)


static func build_icon_cards(size: float, color: Color) -> Control:
	return _icon_texture("cards", size, color)


static func build_icon_gear(size: float, color: Color) -> Control:
	return _icon_texture("gear", size, color)


static func build_icon_swords(size: float, color: Color) -> Control:
	return _icon_texture("swords", size, color)


static func build_icon_trophy(size: float, color: Color) -> Control:
	return _icon_texture("trophy", size, color)


static func build_icon_gift(size: float, color: Color) -> Control:
	return _icon_texture("gift", size, color)


## Persistent bottom tab bar (2026-09-10, explicitly requested after
## initially being scoped out as "navigation architecture, not visual" --
## the user wants it). Not a true single persistent node across scene
## changes (every top-level screen is still its own scene, see the
## project's existing back-button-per-screen pattern) -- each screen builds
## one of these itself via this shared function, with `active` telling it
## which tab to highlight, so it LOOKS like one persistent bar even though
## it's rebuilt fresh per scene. Keeps the change small (no shared-root
## scene refactor) while matching the reference visually and behaviorally.
const TAB_HOME := "home"
const TAB_HEROES := "heroes"
const TAB_SETTINGS := "settings"
const TAB_BATTLE := "battle"

## `in_match`: adds a 4th BATTLE tab and disables the other three -- you
## can't casually tab away mid-match (only the dedicated LEAVE button, with
## its own confirm step, actually exits one), but the reference's battle
## screen shows the full tab bar with Battle lit up rather than hiding it,
## so this renders all four and locks navigation instead of removing tabs.
static func build_tab_bar(parent: Node2D, view_w: float, view_h: float, active: String, in_match: bool = false) -> void:
	var bar_h := 88.0
	var bar := Panel.new()
	bar.position = Vector2(0, view_h - bar_h)
	bar.size = Vector2(view_w, bar_h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.09, 0.96)
	sb.border_width_top = 2
	sb.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.4)
	bar.add_theme_stylebox_override("panel", sb)
	bar.z_index = 20
	parent.add_child(bar)

	var tabs := [
		{"id": TAB_HOME, "label": "HOME", "scene": "res://scenes/main_menu.tscn", "icon": "home"},
		{"id": TAB_HEROES, "label": "HEROES", "scene": "res://scenes/heroes_screen.tscn", "icon": "cards"},
	]
	if in_match:
		tabs.append({"id": TAB_BATTLE, "label": "BATTLE", "scene": "", "icon": "swords"})
	tabs.append({"id": TAB_SETTINGS, "label": "SETTINGS", "scene": "res://scenes/settings_screen.tscn", "icon": "gear"})

	var tab_w := view_w / float(tabs.size())
	for i in tabs.size():
		var t: Dictionary = tabs[i]
		var is_active: bool = t["id"] == active
		var tab_color: Color = CYAN if is_active else TEXT_MUTED

		var btn := Button.new()
		btn.position = Vector2(tab_w * i, 0)
		btn.size = Vector2(tab_w, bar_h)
		btn.flat = true
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		var scene_path: String = t["scene"]
		if not is_active and not in_match:
			btn.pressed.connect(func() -> void: parent.get_tree().change_scene_to_file(scene_path))
		else:
			btn.disabled = true
		bar.add_child(btn)

		var icon_size := 22.0
		var icon: Control
		match String(t["icon"]):
			"home": icon = build_icon_home(icon_size, tab_color)
			"cards": icon = build_icon_cards(icon_size, tab_color)
			"swords": icon = build_icon_swords(icon_size, tab_color)
			_: icon = build_icon_gear(icon_size, tab_color)
		icon.position = Vector2(tab_w * i + (tab_w - icon_size) * 0.5, 12.0)
		bar.add_child(icon)

		var label := Label.new()
		label.position = Vector2(tab_w * i, 38.0)
		label.size = Vector2(tab_w, bar_h - 38.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", BODY_FONT_SEMIBOLD)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", tab_color)
		label.text = t["label"]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(label)
