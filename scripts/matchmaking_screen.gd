extends Node2D
## "Searching for opponent" theater for CASUAL matches only (see
## game_state.gd's doc comment) -- there is no real PvP in this project,
## every match is UnitDatabase.random_bot_hand(). This screen exists purely
## to give a casual match the same satisfying "found a real opponent" beat
## Draft Showdown's own matchmaking screen has, in the one mode where doing
## so costs nothing if a player ever suspects it: no rating is on the line
## here (that's RANKED, which skips this screen entirely and goes straight
## to the draft -- see main_menu.gd).
##
## Flow: flicker through candidate names for SEARCH_TIME (mimics a live
## search), lock onto the final one for LOCK_TIME (the "found them" beat),
## then hand off to the draft screen. The locked name is stashed on
## GameState so match_controller.gd can reference it in the result text.

const VIEW_W := 720.0
const VIEW_H := 1280.0

const BG_COLOR := Color(0.05, 0.06, 0.09)
const ACCENT := Color(0.25, 0.85, 0.95)
const GOLD := Color(1.0, 0.78, 0.25)
const MUTED_TEXT := Color(0.62, 0.66, 0.74)

const SEARCH_TIME := 1.4
const LOCK_TIME := 0.9
const FLICKER_INTERVAL := 0.1

const NAME_PREFIXES := [
	"GHOST", "RAZOR", "NEON", "VOID", "CIPHER", "GLITCH", "GRIM", "STATIC",
	"VORTEX", "ZERO", "NOVA", "WRAITH", "BLADE", "ECHO", "FROST", "SHARD",
]

var _opponent_label: Label
var _status_label: Label
var _elapsed := 0.0
var _flicker_timer := 0.0
var _locked := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	_build_card("YOU", "%d BITS" % PlayerProfile.currency, 260.0, ACCENT)

	var vs_label := Label.new()
	vs_label.position = Vector2(0, 560.0)
	vs_label.size = Vector2(VIEW_W, 60)
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 40)
	vs_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	vs_label.text = "VS"
	add_child(vs_label)

	_opponent_label = _build_card("???", "", 700.0, GOLD)

	_status_label = Label.new()
	_status_label.position = Vector2(0, 980.0)
	_status_label.size = Vector2(VIEW_W, 40)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", MUTED_TEXT)
	_status_label.text = "Searching for opponent…"
	add_child(_status_label)

	_reroll_opponent_name()


func _build_card(name_text: String, sub_text: String, y: float, accent: Color) -> Label:
	var panel := Panel.new()
	panel.position = Vector2(60.0, y)
	panel.size = Vector2(VIEW_W - 120.0, 140.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.19)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = accent
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var name_label := Label.new()
	name_label.position = Vector2(0, 30.0)
	name_label.size = Vector2(panel.size.x, 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	name_label.text = name_text
	panel.add_child(name_label)

	if not sub_text.is_empty():
		var sub_label := Label.new()
		sub_label.position = Vector2(0, 82.0)
		sub_label.size = Vector2(panel.size.x, 30)
		sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_label.add_theme_font_size_override("font_size", 16)
		sub_label.add_theme_color_override("font_color", accent)
		sub_label.text = sub_text
		panel.add_child(sub_label)

	return name_label


func _random_name() -> String:
	var prefix: String = NAME_PREFIXES[randi() % NAME_PREFIXES.size()]
	return "%s_%d" % [prefix, randi_range(10, 999)]


func _reroll_opponent_name() -> void:
	_opponent_label.text = _random_name()


func _process(delta: float) -> void:
	_elapsed += delta

	if not _locked:
		_flicker_timer += delta
		if _flicker_timer >= FLICKER_INTERVAL:
			_flicker_timer = 0.0
			_reroll_opponent_name()

		if _elapsed >= SEARCH_TIME:
			_locked = true
			GameState.casual_opponent_name = _opponent_label.text
			_opponent_label.add_theme_color_override("font_color", GOLD)
			_status_label.text = "MATCH FOUND!"
			_status_label.add_theme_color_override("font_color", GOLD)
	elif _elapsed >= SEARCH_TIME + LOCK_TIME:
		get_tree().change_scene_to_file("res://scenes/draft_screen.tscn")
