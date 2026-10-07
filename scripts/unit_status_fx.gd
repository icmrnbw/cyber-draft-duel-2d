extends Node2D
## Presentation-only, one bounded overlay per unit. Never writes combat state.
const SHIELD := preload("res://assets/vfx/aegis_shield.png")
var unit: SimUnit
var radius := 45.0
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	visible = unit != null and unit.alive
	if visible:
		queue_redraw()

func _draw() -> void:
	if unit == null or not unit.alive:
		return
	var pulse := 0.5 + 0.5 * sin(clock * 5.0)
	if unit.shield > 0.0:
		var r := radius * (1.16 + pulse * 0.025)
		draw_texture_rect(SHIELD, Rect2(Vector2(-r, -r * 1.2), Vector2(r * 2.0, r * 2.4)), false, Color(1, 1, 1, 0.32 + pulse * 0.12))
		draw_line(Vector2(-radius, -radius * 1.3), Vector2(-radius + radius * 2.0 * minf(unit.shield / maxf(unit.max_hp() * 0.25, 1.0), 1.0), -radius * 1.3), Color("8ffbff"), 4)
	if unit.vulnerability_timer > 0.0:
		var r := radius * 0.75
		for i in range(4):
			var angle := float(i) * PI * 0.5 + clock * 0.25
			draw_arc(Vector2.ZERO, r, angle, angle + 0.45, 8, Color("ff904d"), 3.0, true)
	if unit.slow_timer > 0.0:
		draw_arc(Vector2(0, radius * 0.8), radius * 0.58, 0, TAU, 24, Color(0.4, 0.85, 1, 0.75), 3.0, true)
	if unit.suppression_timer > 0.0:
		for i in range(2):
			var y := -radius * 0.8 + i * 9.0
			draw_polyline(PackedVector2Array([Vector2(-8,y), Vector2(0,y+6), Vector2(8,y)]), Color("d995ff"), 3.0, true)
	if unit.control_immunity_timer > 0.0:
		draw_arc(Vector2.ZERO, radius * 1.02, clock * 2, clock * 2 + PI, 24, Color("abffcf"), 3.0, true)
	var def := unit.def
	if def.berserk_min_level > 0 and unit.level >= def.berserk_min_level:
		var intensity := 1.0 - unit.hp_fraction()
		if intensity > 0.1:
			for i in range(3):
				var angle := clock * (2.0 + intensity * 4) + i * TAU / 3.0
				draw_arc(Vector2.ZERO, radius * (0.7 + pulse * 0.1), angle, angle + 0.65, 8, Color(1.0, 0.32, 0.06, intensity), 2.0 + intensity * 2, true)
