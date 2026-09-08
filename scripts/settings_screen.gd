extends Node2D
## Minimal settings: sound toggle + a visible reset for the local save.
## Deliberately small -- a real settings screen isn't the retention hook, but
## having SOMEWHERE to put "turn the sound off" and "wipe my progress" is
## table stakes, and the reset is genuinely useful while testing progression.

const VIEW_W := 720.0
const VIEW_H := 1280.0

const BG_COLOR := Color(0.05, 0.06, 0.09)
const CARD_BG := Color(0.11, 0.13, 0.19)
const ACCENT := Color(0.25, 0.85, 0.95)
const MUTED_TEXT := Color(0.62, 0.66, 0.74)

var _sfx_button: Button
var _reset_button: Button
var _reset_armed := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	var title := Label.new()
	title.position = Vector2(0, 60)
	title.size = Vector2(VIEW_W, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	title.text = "SETTINGS"
	add_child(title)

	_sfx_button = _button("", 200.0, Color(0.13, 0.15, 0.2), ACCENT)
	_sfx_button.pressed.connect(_on_sfx_toggled)

	_reset_button = _button("RESET PROGRESS", 300.0, Color(0.2, 0.08, 0.09), Color(0.8, 0.3, 0.3))
	_reset_button.pressed.connect(_on_reset_pressed)

	var back := _button("BACK", VIEW_H - 140.0, Color(0.14, 0.16, 0.23), MUTED_TEXT)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

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


func _button(text: String, y: float, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(VIEW_W * 0.5 - 200.0, y)
	b.size = Vector2(400.0, 70.0)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", _rounded_style(bg, border))
	b.add_theme_stylebox_override("hover", _rounded_style(bg.lightened(0.08), border, 3))
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
