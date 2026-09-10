extends Node2D
## Minimal settings: sound toggle + a visible reset for the local save.
## Deliberately small -- a real settings screen isn't the retention hook, but
## having SOMEWHERE to put "turn the sound off" and "wipe my progress" is
## table stakes, and the reset is genuinely useful while testing progression.
##
## Rebuilt 2026-09-10 in the UITheme neon language -- this screen had only
## gotten the bottom tab bar in the first redesign pass; everything else was
## still plain default-theme buttons on a flat dark background, which read as
## completely unfinished next to the rest of the app.

const VIEW_W := 720.0
const VIEW_H := 1280.0

const MUTED_TEXT := UITheme.TEXT_MUTED

var _sfx_button: Button
var _reset_button: Button
var _reset_armed := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	# Same shared cyberpunk-city backdrop as Main Menu/Heroes/Draft.
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/app_background.png")
	backdrop.size = Vector2(VIEW_W, VIEW_H)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(1, 1, 1, 0.5)
	add_child(backdrop)

	var title := Label.new()
	title.position = Vector2(0, 60)
	title.size = Vector2(VIEW_W, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UITheme.CYAN)
	title.text = "SETTINGS"
	add_child(title)

	_sfx_button = _button("", 200.0, UITheme.CYAN)
	_sfx_button.pressed.connect(_on_sfx_toggled)

	_reset_button = _button("RESET PROGRESS", 300.0, Color(0.85, 0.35, 0.35))
	_reset_button.pressed.connect(_on_reset_pressed)

	var back := _button("BACK", VIEW_H - 240.0, MUTED_TEXT)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

	UITheme.build_tab_bar(self, VIEW_W, VIEW_H, UITheme.TAB_SETTINGS)
	_refresh()


func _rounded_style(bg_color: Color, border_color: Color, border_w: int = 2, radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border_color
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	return sb


## A dark filled panel + a glowing gradient border overlay (same layered
## pattern as UITheme cards elsewhere) instead of a plain StyleBoxFlat
## border, so these buttons actually match the neon language.
func _button(text: String, y: float, accent: Color) -> Button:
	var size := Vector2(400.0, 70.0)
	var pos := Vector2(VIEW_W * 0.5 - size.x * 0.5, y)

	var bg_panel := Panel.new()
	bg_panel.position = pos
	bg_panel.size = size
	bg_panel.add_theme_stylebox_override("panel", _rounded_style(UITheme.CARD_BG, Color.TRANSPARENT, 0, 16))
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_panel)

	var border := UITheme.build_gradient_panel(size, 16.0, 2.0, false, accent, accent.lightened(0.3), 0.8)
	border.position = pos
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.flat = true
	b.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	b.add_theme_color_override("font_hover_color", UITheme.TEXT_BRIGHT)
	add_child(b)
	return b


func _on_sfx_toggled() -> void:
	GameSettings.sfx_enabled = not GameSettings.sfx_enabled
	GameSettings.save()
	_refresh()


## Two-step so a mis-tap can't wipe a save: first press arms, second confirms.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_refresh()
		return
	PlayerProfile.reset_progress()
	_reset_armed = false
	_refresh()


func _refresh() -> void:
	_sfx_button.text = "SOUND:  %s" % ("ON" if GameSettings.sfx_enabled else "OFF")
	_reset_button.text = "TAP AGAIN TO CONFIRM" if _reset_armed else "RESET PROGRESS"
