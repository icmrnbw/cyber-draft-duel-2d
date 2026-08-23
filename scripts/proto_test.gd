extends Node2D
## First proof-of-concept for the Draft-Showdown-style pivot: portrait viewport,
## a vertical lane, and a chibi 2D sprite animated ENTIRELY procedurally (no
## Spine/DragonBones, no skeleton, no clip library) -- idle bob via a sine wave,
## attack via a simple scale/position punch tween. If this reads as "alive"
## on its own, external animation tooling probably isn't needed for this style.

const LANE_WIDTH := 360.0
const VIEW_W := 720.0
const VIEW_H := 1280.0

var _idle_phase := 0.0
var _sprite_a: Sprite2D
var _sprite_b: Sprite2D
var _base_scale := Vector2(0.35, 0.35)


func _ready() -> void:
	_build_background()
	_sprite_a = _build_unit(Vector2(VIEW_W * 0.5, VIEW_H * 0.78), Color(0.15, 0.75, 1.0))
	_sprite_b = _build_unit(Vector2(VIEW_W * 0.5, VIEW_H * 0.22), Color(1.0, 0.42, 0.2))
	# Deliberately NOT flipped -- tried flip_v first, it just reads as upside-down
	# for a front-facing chibi portrait (this isn't a side-view sprite). Draft
	# Showdown's own screenshots show both sides facing the camera too, not each
	# other -- matching that instead of fighting the art style.

	# Demo-only: alternate a simple attack lunge every couple seconds so both
	# procedural states (idle sway, attack punch) are visible without input.
	var timer := Timer.new()
	timer.wait_time = 2.2
	timer.autostart = true
	timer.timeout.connect(_on_attack_tick)
	add_child(timer)


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	var lane := ColorRect.new()
	lane.color = Color(0.11, 0.13, 0.17)
	lane.size = Vector2(LANE_WIDTH, VIEW_H)
	lane.position = Vector2((VIEW_W - LANE_WIDTH) * 0.5, 0)
	add_child(lane)

	# Centre line, purely cosmetic -- same idea as battle_controller.gd's 3D one.
	var mid := ColorRect.new()
	mid.color = Color(0.3, 0.34, 0.4, 0.6)
	mid.size = Vector2(LANE_WIDTH, 3)
	mid.position = Vector2((VIEW_W - LANE_WIDTH) * 0.5, VIEW_H * 0.5)
	add_child(mid)


func _build_unit(pos: Vector2, team_color: Color) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/trooper_chibi_transparent.png")
	sprite.position = pos
	sprite.scale = _base_scale
	add_child(sprite)

	# Ground shadow + team-colour accent ring, same visual language as the 3D
	# game's "accent ring" -- team reads by colour, not by character design.
	var ring := ColorRect.new()
	ring.color = team_color
	ring.color.a = 0.85
	ring.size = Vector2(90, 18)
	ring.position = pos - Vector2(45, -155)
	ring.z_index = -1
	add_child(ring)

	return sprite


func _on_attack_tick() -> void:
	_punch(_sprite_a, false)
	_punch(_sprite_b, true)


func _punch(sprite: Sprite2D, flipped: bool) -> void:
	var tw := create_tween()
	var lunge := -40.0 if not flipped else 40.0
	tw.tween_property(sprite, "position:y", sprite.position.y + lunge, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:y", sprite.position.y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(sprite, "scale", _base_scale * 1.12, 0.1)
	tw.chain().tween_property(sprite, "scale", _base_scale, 0.2)


func _process(delta: float) -> void:
	# Idle sway -- pure sine wave on scale + a tiny rotation wobble, exactly the
	# "procedural fallback" technique unit_view.gd already used for units with
	# no authored idle clip. No external animation tool involved at all.
	# First pass here used a 0.015 scale amplitude, invisible at this render
	# scale -- same mistake as the 3D idle animations earlier (tuned against a
	# close-up, not the actual on-screen size). Roughly 5x bigger this time,
	# checked against a real screenshot before trusting it.
	_idle_phase += delta * 2.0
	var bob := sin(_idle_phase) * 0.07
	_sprite_a.scale = _base_scale + Vector2(bob, -bob)
	_sprite_b.scale = _base_scale + Vector2(-bob, bob)
	_sprite_a.rotation = sin(_idle_phase * 0.7) * 0.09
	_sprite_b.rotation = -sin(_idle_phase * 0.7) * 0.09
	_sprite_a.position.y = VIEW_H * 0.78 + sin(_idle_phase) * 6.0
	_sprite_b.position.y = VIEW_H * 0.22 - sin(_idle_phase) * 6.0
