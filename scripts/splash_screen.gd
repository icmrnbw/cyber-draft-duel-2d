extends Node2D
## App entry point / title screen (2026-09-10, new -- the project had no
## splash screen before this; main_menu.tscn was launched directly). Modeled
## on the reference mobile UI mockup's splash screen: logo lockup, tagline,
## a glowing pedestal, and a single "GET STARTED" CTA into the real flow.
## Purely a front door -- no state read or written here.

const VIEW_W := 720.0
const VIEW_H := 1280.0

var _pulse_phase: float = 0.0
var _badge: Control


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/app_background.png")
	backdrop.size = Vector2(VIEW_W, VIEW_H)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(1, 1, 1, 0.6)
	add_child(backdrop)

	# Glowing hex badge "pedestal" -- the mockup's floating diamond/crest
	# icon above the title, built from the same hex-badge shape used
	# elsewhere (UITheme.build_hex_badge) rather than a new art asset.
	_badge = UITheme.build_hex_badge("", 46.0)
	_badge.position = Vector2(VIEW_W * 0.5 - _badge.size.x * 0.5, 300.0)
	add_child(_badge)

	var title1 := Label.new()
	title1.position = Vector2(0, 460.0)
	title1.size = Vector2(VIEW_W, 50.0)
	title1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title1.add_theme_font_override("font", UITheme.HEADER_FONT)
	title1.add_theme_font_size_override("font_size", 34)
	title1.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	title1.text = "CYBER"
	add_child(title1)

	var title2 := Label.new()
	title2.position = Vector2(0, 508.0)
	title2.size = Vector2(VIEW_W, 60.0)
	title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title2.add_theme_font_override("font", UITheme.HEADER_FONT)
	title2.add_theme_font_size_override("font_size", 44)
	title2.add_theme_color_override("font_color", UITheme.CYAN)
	title2.text = "DRAFT-DUEL"
	add_child(title2)

	var subtitle := Label.new()
	subtitle.position = Vector2(0, 590.0)
	subtitle.size = Vector2(VIEW_W, 26)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	subtitle.text = "D R A F T   /   B A T T L E   /   C L I M B"
	add_child(subtitle)

	var tagline := Label.new()
	tagline.position = Vector2(0, VIEW_H - 260.0)
	tagline.size = Vector2(VIEW_W, 60)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_override("font", UITheme.BODY_FONT)
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	tagline.text = "S T R A T E G Y   C R E A T E S\nL E G E N D S"
	add_child(tagline)

	var cta := UITheme.build_gradient_button("GET STARTED", Vector2(VIEW_W - 60.0, 76.0))
	cta["container"].position = Vector2(30.0, VIEW_H - 150.0)
	add_child(cta["container"])
	cta["button"].pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))


func _process(delta: float) -> void:
	_pulse_phase += delta
	if _badge:
		var s := 1.0 + sin(_pulse_phase * 1.6) * 0.06
		_badge.scale = Vector2(s, s)
