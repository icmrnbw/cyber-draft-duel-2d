extends Node2D
## Unit detail screen (2026-09-10, new -- the reference mobile UI mockup's
## "Card Detail" screen had no equivalent here before this). The mockup's
## specific content (numbered mana-cost hexagons, a "Shield" keyword, a
## draw-a-card ability, #Draw/#Cyber tags) is TCG mechanics this project
## doesn't have and was never going to get (see the visual-language-only
## redesign decision) -- but its LAYOUT (big glowing portrait, name +
## rarity-equivalent, description, tag pills, bottom CTA) maps cleanly onto
## something real: a closer look at one of our 5 actual units, opened from
## Heroes or Draft, showing its real stats/abilities and the same "unlock
## next tier" action Heroes already has inline.
##
## Reads GameState.detail_unit_path (set by whichever screen opened this) to
## know which unit to show -- scene changes are stateless, so the unit
## can't be passed as a constructor argument.

const TeamColor := preload("res://scripts/team_color.gd")

const VIEW_W := 720.0
const VIEW_H := 1280.0

var _unit_def: UnitDefinition
var _portrait: TextureRect
var _portrait_blend: TextureRect
var _breathe_phase: float = 0.0
const BREATHE_PERIOD := 0.9

var _unlock_button: Button
var _unlock_container: Control


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
	backdrop.modulate = Color(1, 1, 1, 0.4)
	add_child(backdrop)

	_unit_def = load(GameState.detail_unit_path) as UnitDefinition
	if _unit_def == null:
		# Nothing to show (opened with no context, e.g. a fresh scene reload
		# during dev) -- fall back to the first roster unit rather than
		# crashing on a null dereference below.
		_unit_def = UnitDatabase.roster()[0]

	_build_header()
	_build_card()
	_build_tags()
	_build_stats()
	_build_cta()
	_refresh()


func _process(delta: float) -> void:
	_breathe_phase += delta
	var frames := _unit_def.idle_frames_for_level(PlayerProfile.max_unlocked_level(_unit_def))
	if frames.size() < 2:
		_portrait_blend.visible = false
		return
	var n := frames.size()
	var loop_t := fmod(_breathe_phase / BREATHE_PERIOD, 1.0) * n
	var idx := int(loop_t) % n
	var next_idx := (idx + 1) % n
	var frac: float = loop_t - float(int(loop_t))
	_portrait.texture = frames[idx]
	_portrait_blend.texture = frames[next_idx]
	_portrait_blend.modulate.a = frac
	_portrait_blend.visible = true


func _build_header() -> void:
	var back := Button.new()
	back.position = Vector2(20.0, 24.0)
	back.size = Vector2(44.0, 44.0)
	back.flat = true
	back.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	back.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/heroes_screen.tscn"))
	add_child(back)

	var arrow := Line2D.new()
	arrow.points = PackedVector2Array([Vector2(27, 9), Vector2(13, 22), Vector2(27, 35)])
	arrow.default_color = UITheme.TEXT_BRIGHT
	arrow.width = 3.0
	arrow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.end_cap_mode = Line2D.LINE_CAP_ROUND
	arrow.joint_mode = Line2D.LINE_JOINT_ROUND
	back.add_child(arrow)


func _type_accent(t: int) -> Color:
	return UITheme.VIOLET if t == UnitDefinition.UnitType.LONG else UITheme.CYAN


func _type_label(t: int) -> String:
	match t:
		UnitDefinition.UnitType.MELEE: return "TANK"
		UnitDefinition.UnitType.MID: return "TROOPER"
		UnitDefinition.UnitType.LONG: return "RANGED"
		UnitDefinition.UnitType.SUPPORT: return "SUPPORT"
	return ""


func _build_card() -> void:
	var accent := _type_accent(_unit_def.type)
	var card_pos := Vector2(50.0, 100.0)
	var card_size := Vector2(VIEW_W - 100.0, 480.0)

	var bg_panel := Panel.new()
	bg_panel.position = card_pos
	bg_panel.size = card_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD_BG
	sb.set_corner_radius_all(28)
	bg_panel.add_theme_stylebox_override("panel", sb)
	add_child(bg_panel)

	var border := UITheme.build_gradient_panel(card_size, 28.0, 2.5, false, accent, accent.lightened(0.3), 1.0)
	border.position = card_pos
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

	var badge := UITheme.build_hex_badge(str(PlayerProfile.max_unlocked_level(_unit_def)), 26.0)
	badge.position = card_pos + Vector2(14.0, 14.0)
	add_child(badge)

	var portrait_size := Vector2(card_size.x - 60.0, 340.0)
	_portrait = TextureRect.new()
	_portrait.position = card_pos + Vector2((card_size.x - portrait_size.x) * 0.5, 26.0)
	_portrait.size = portrait_size
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture = _unit_def.idle_sprite_for_level(PlayerProfile.max_unlocked_level(_unit_def))
	TeamColor.apply_vibrance_only(_portrait)
	add_child(_portrait)

	_portrait_blend = TextureRect.new()
	_portrait_blend.size = _portrait.size
	_portrait_blend.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait_blend.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_blend.visible = false
	TeamColor.apply_vibrance_only(_portrait_blend)
	_portrait.add_child(_portrait_blend)

	var name_label := Label.new()
	name_label.position = card_pos + Vector2(0, 378.0)
	name_label.size = Vector2(card_size.x, 40)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UITheme.HEADER_FONT)
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	name_label.text = _unit_def.display_name.to_upper()
	add_child(name_label)

	var type_label := Label.new()
	type_label.position = card_pos + Vector2(0, 420.0)
	type_label.size = Vector2(card_size.x, 26)
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	type_label.add_theme_font_size_override("font_size", 15)
	type_label.add_theme_color_override("font_color", accent)
	type_label.text = _type_label(_unit_def.type)
	add_child(type_label)

	var desc_label := Label.new()
	desc_label.position = Vector2(50.0, 600.0)
	desc_label.size = Vector2(VIEW_W - 100.0, 60)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_override("font", UITheme.BODY_FONT)
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	desc_label.text = _unit_def.description
	add_child(desc_label)


## Real ability/role tags instead of the reference's TCG keywords (#Shield,
## #Draw) -- derived from this unit's actual UnitDefinition fields so they
## can't drift out of sync with what the unit actually does in battle.
func _build_tags() -> void:
	var tags: Array[String] = [_type_label(_unit_def.type)]
	if _unit_def.is_support:
		tags.append("HEALER")
	if _unit_def.splash_radius > 0.0:
		tags.append("SPLASH")
	if _unit_def.stagger_chance > 0.0:
		tags.append("STAGGER")
	if _unit_def.berserk_min_level > 0:
		tags.append("BERSERK")
	if _unit_def.self_defense_damage > 0.0:
		tags.append("SELF-DEFENSE")

	var x := 50.0
	var y := 670.0
	for tag in tags:
		var w := 24.0 + tag.length() * 8.0
		if x + w > VIEW_W - 50.0:
			x = 50.0
			y += 34.0
		var pill_size := Vector2(w, 28.0)
		var pill := UITheme.build_gradient_panel(pill_size, 14.0, 1.5, false, UITheme.CYAN, UITheme.VIOLET, 0.5)
		pill.position = Vector2(x, y)
		add_child(pill)
		var lbl := Label.new()
		lbl.position = Vector2(x, y)
		lbl.size = pill_size
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		lbl.text = "#" + tag
		add_child(lbl)
		x += w + 10.0


func _build_stats() -> void:
	var y := 740.0
	var stats := [
		["HP", str(roundi(_unit_def.hp))],
		["DPS", str(roundi(_unit_def.dps()))],
		["SPEED", "%.1f m/s" % _unit_def.move_speed],
		["RANGE", "%.1f m" % _unit_def.preferred_range],
	]
	var col_gap := 30.0
	var col_w := (VIEW_W - 100.0 - col_gap) * 0.5
	for i in stats.size():
		var row := i / 2
		var col := i % 2
		var pos := Vector2(50.0 + col * (col_w + col_gap), y + row * 46.0)
		var caption := Label.new()
		caption.position = pos
		caption.size = Vector2(col_w * 0.4, 30)
		caption.add_theme_font_override("font", UITheme.BODY_FONT)
		caption.add_theme_font_size_override("font_size", 14)
		caption.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		caption.text = stats[i][0]
		add_child(caption)

		var value := Label.new()
		value.position = pos + Vector2(col_w * 0.4, 0)
		value.size = Vector2(col_w * 0.6, 30)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		value.add_theme_font_size_override("font_size", 17)
		value.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		value.text = stats[i][1]
		add_child(value)


func _build_cta() -> void:
	var cta := UITheme.build_gradient_button("", Vector2(VIEW_W - 60.0, 76.0))
	cta["container"].position = Vector2(30.0, VIEW_H - 150.0)
	add_child(cta["container"])
	cta["button"].pressed.connect(_on_cta_pressed)
	_unlock_button = cta["button"]
	_unlock_container = cta["container"]


func _on_cta_pressed() -> void:
	if PlayerProfile.unlock_next_tier(_unit_def):
		_refresh()


func _refresh() -> void:
	var tier := PlayerProfile.unlocked_tier(_unit_def)
	var label: Label = _unlock_container.get_child(1)
	if tier >= PlayerProfile.MAX_TIERS:
		label.text = "FULLY UNLOCKED"
		_unlock_button.disabled = true
		_unlock_container.modulate.a = 0.6
	else:
		var cost := PlayerProfile.next_tier_cost(_unit_def)
		var affordable := PlayerProfile.currency >= cost
		label.text = "UNLOCK Lv.%d — %d BITS" % [PlayerProfile.max_unlocked_level(_unit_def) + 1, cost]
		_unlock_button.disabled = not affordable
		_unlock_container.modulate.a = 1.0 if affordable else 0.55
