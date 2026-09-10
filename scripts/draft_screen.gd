extends Node2D
## Draft screen: tap a unit card to fill the next hand slot. Each of the 5
## unit types can only be picked ONCE per hand (2026-09-10, re-restored --
## a 2026-09-07 change briefly allowed duplicates, which the user then
## clarified was a miscommunication: the intended design is "pick 4
## DIFFERENT units up front, then in-match offers only ever draw from those
## 4" -- i.e. the original 2026-08-26 rule, which this restores verbatim).
## With HAND_SIZE=4 and 5 types total, a hand is always 4 distinct types
## with exactly one type left undrafted. In-match growth offers are scoped
## to type_pool (the distinct types in the drafted hand, see round_state.gd)
## regardless of this rule, so that part of the design was never broken by
## the duplicates experiment -- only the draft screen's own pick rule was.
## "Ready" unlocks once all HAND_SIZE slots are full, then hands off to
## GameState.start_match() -> scenes/match.tscn.
##
## Rebuilt 2026-09-10 in the UITheme neon-cyberpunk language (see
## scripts/ui_theme.gd and the "draft/growth cards" reference mockup this
## replaces): glowing gradient-bordered slots/cards, a hex timer badge,
## per-type accent pills, and a procedural checkmark on picked cards,
## instead of the previous flat-accent dark-card style.

const TeamColor := preload("res://scripts/team_color.gd")

const VIEW_W := 720.0
const VIEW_H := 1280.0

const BG_COLOR := UITheme.BG
const CARD_BG := UITheme.CARD_BG
const ACCENT := UITheme.CYAN
const GOLD := Color(1.0, 0.82, 0.3)
const MUTED_TEXT := UITheme.TEXT_MUTED
const READY_GREEN := Color(0.35, 0.95, 0.55)

const SLOT_SIZE := Vector2(140.0, 140.0)
const CARD_SIZE := Vector2(660.0, 148.0)
const PORTRAIT_SIZE := Vector2(112.0, 112.0)
const STATS_COL_W := 134.0

var _hand: Array[UnitDefinition] = []
var _slot_bg_panels: Array[NinePatchRect] = []
var _slot_portraits: Array[TextureRect] = []
var _slot_blends: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _slot_plus: Array[Label] = []

var _unit_card_containers: Array[Control] = []
var _unit_card_buttons: Array[Button] = []
var _unit_card_checks: Array[Control] = []
var _card_portraits: Array[TextureRect] = []
var _card_blends: Array[TextureRect] = []
var _card_defs: Array[UnitDefinition] = []
var _ready_button: Button
var _clear_button: Button
var _breathe_phase: float = 0.0

## 1.8s (4 keyframes -> 0.45s hold = ~2.2 changes/sec) read as "2fps," not
## breathing -- a slow crossfade between only 2 sparse still images doesn't
## look like motion, it looks like a slideshow. Halved (2026-09-10).
const BREATHE_PERIOD := 0.9

## A generous soft timer, not a punishing one -- there's no real opponent
## waiting on you (see game_state.gd's doc comment, every match is vs a bot),
## so this exists purely for pace/tension, the same reason drafting games
## conventionally have one, not because anything is actually blocked on it.
## Timing out doesn't cost anything beyond losing the choice: it just
## auto-fills whatever's left with random undrafted types and proceeds,
## the same as a player who was indecisive and ran out of picks.
const DRAFT_TIME_LIMIT := 30.0
var _time_remaining: float = DRAFT_TIME_LIMIT
var _timer_hex: Control
var _timer_label: Label
var _draft_finished := false


## Real 4-frame breathing loop (see UnitDefinition.idle_frames), same art and
## cadence as in-battle idle units and the Heroes page -- replaces an earlier
## sine-scale/rotation wobble on the flat static portrait, which wasn't a
## real animation and looked bad. Drafting is always Lv.1, so this always
## uses the base idle_frames (no per-unit tier to resolve here).
##
## Crossfades the upcoming frame in over a child overlay TextureRect (same
## trick as match_controller.gd's idle_blend / heroes_screen.gd) instead of
## hard-swapping .texture -- a plain swap read as robotic/choppy, no
## transition between poses. The overlay is a CHILD of the portrait (not a
## sibling) specifically so an empty hand slot's portrait.visible = false
## (see _refresh()) hides the blend too, for free.
func _process(delta: float) -> void:
	_breathe_phase += delta
	for i in _slot_portraits.size():
		if i >= _hand.size():
			continue
		_animate_portrait(_slot_portraits[i], _slot_blends[i], _hand[i], i)
	for i in _card_portraits.size():
		_animate_portrait(_card_portraits[i], _card_blends[i], _card_defs[i], _slot_portraits.size() + i)

	if _draft_finished:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	var secs := int(ceil(_time_remaining))
	_timer_label.text = "0:%02d" % secs
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35) if secs <= 5 else UITheme.TEXT_BRIGHT)
	if _time_remaining <= 0.0:
		_auto_finish_draft()


func _animate_portrait(portrait: TextureRect, blend: TextureRect, def: UnitDefinition, phase_index: int) -> void:
	var frames := def.idle_frames_for_level(1)
	if frames.size() < 2:
		blend.visible = false
		return
	var n := frames.size()
	var loop_t := fmod(_breathe_phase / BREATHE_PERIOD + float(phase_index) * 0.27, 1.0) * n
	var idx := int(loop_t) % n
	var next_idx := (idx + 1) % n
	var frac: float = loop_t - float(int(loop_t))
	# See heroes_screen.gd's identical fix -- a straight linear crossfade
	# spends too long near 50/50 opacity when a weapon's position differs
	# between breathing frames, reading as a doubled weapon. Hold clean,
	# blend only through a brief middle window.
	var blend_alpha := clampf((frac - 0.35) / 0.3, 0.0, 1.0)
	portrait.texture = frames[idx]
	blend.texture = frames[next_idx]
	blend.modulate.a = blend_alpha
	blend.visible = true


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	# Same shared cyberpunk-city backdrop as Main Menu/Heroes/Settings.
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/app_background.png")
	backdrop.size = Vector2(VIEW_W, VIEW_H)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(1, 1, 1, 0.4)
	add_child(backdrop)

	_build_header()
	_build_slots()
	_build_unit_cards()
	_build_actions()
	# Drafting isn't a persistent tab of its own -- it's reached via the
	# Home screen's CASUAL/RANKED tiles, so Home stays highlighted here
	# rather than passing TAB_BATTLE (which, without in_match=true, never
	# gets added to the bar at all and left nothing highlighted).
	UITheme.build_tab_bar(self, VIEW_W, VIEW_H, UITheme.TAB_HOME)
	_refresh()


func _rounded_style(bg_color: Color, border_color: Color, border_w: int = 0, radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border_color
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.35)
	return sb


func _build_header() -> void:
	# Drafting is a sub-flow of the main menu now, not the app's front door,
	# so it needs a way back out. (The old HEROES shortcut that lived here
	# moved to the main menu, which is where it belongs.)
	var back_button := Button.new()
	back_button.text = "← BACK"
	back_button.position = Vector2(20.0, 18.0)
	back_button.size = Vector2(96.0, 34.0)
	back_button.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	back_button.add_theme_font_size_override("font_size", 13)
	back_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.14, 0.16, 0.23), MUTED_TEXT, 2, 12))
	back_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.17, 0.19, 0.27), Color(0.8, 0.83, 0.9), 2, 12))
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back_button)

	# Hex timer badge, top-right -- the mockup's glowing hexagon countdown
	# instead of a plain corner label.
	_timer_hex = UITheme.build_hex_badge("0:30", 26.0)
	_timer_hex.position = Vector2(VIEW_W - _timer_hex.size.x - 20.0, 12.0)
	add_child(_timer_hex)
	_timer_label = _timer_hex.get_child(3) as Label
	_timer_label.add_theme_font_size_override("font_size", 15)

	var title := Label.new()
	title.position = Vector2(0, 60)
	title.size = Vector2(VIEW_W, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.CYAN)
	title.text = "DRAFT YOUR SQUAD"
	add_child(title)

	var mode_label := Label.new()
	mode_label.position = Vector2(0, 100)
	mode_label.size = Vector2(VIEW_W, 24)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	mode_label.add_theme_font_size_override("font_size", 13)
	mode_label.add_theme_color_override("font_color", ACCENT if GameState.ranked else GOLD)
	mode_label.text = "RANKED MATCH" if GameState.ranked else "CASUAL MATCH"
	add_child(mode_label)


func _build_slots() -> void:
	var gap := 12.0
	var total_w := UnitDatabase.HAND_SIZE * SLOT_SIZE.x + (UnitDatabase.HAND_SIZE - 1) * gap
	var start_x := (VIEW_W - total_w) * 0.5
	var y := 136.0
	for i in range(UnitDatabase.HAND_SIZE):
		var pos := Vector2(start_x + i * (SLOT_SIZE.x + gap), y)

		var bg_panel := UITheme.build_painted_panel(SLOT_SIZE)
		bg_panel.position = pos
		add_child(bg_panel)

		var plus := Label.new()
		plus.position = pos + Vector2(0, -8)
		plus.size = SLOT_SIZE
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		plus.add_theme_font_override("font", UITheme.HEADER_FONT)
		plus.add_theme_font_size_override("font_size", 40)
		plus.add_theme_color_override("font_color", MUTED_TEXT)
		plus.text = "+"
		add_child(plus)
		_slot_plus.append(plus)

		var portrait := TextureRect.new()
		portrait.position = pos + Vector2(14, 8)
		portrait.size = SLOT_SIZE - Vector2(28, 42)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.visible = false
		TeamColor.apply_vibrance_only(portrait)
		add_child(portrait)

		var blend := TextureRect.new()
		blend.position = Vector2.ZERO
		blend.size = portrait.size
		blend.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		blend.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		blend.visible = false
		TeamColor.apply_vibrance_only(blend)
		portrait.add_child(blend)

		var label := Label.new()
		label.position = pos + Vector2(0, SLOT_SIZE.y - 30)
		label.size = Vector2(SLOT_SIZE.x, 26)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MUTED_TEXT)
		label.text = "SLOT %d" % (i + 1)
		add_child(label)

		_slot_bg_panels.append(bg_panel)
		_slot_portraits.append(portrait)
		_slot_blends.append(blend)
		_slot_labels.append(label)


func _type_label(t: int) -> String:
	match t:
		UnitDefinition.UnitType.MELEE: return "TANK"
		UnitDefinition.UnitType.MID: return "TROOPER"
		UnitDefinition.UnitType.LONG: return "RANGED"
		UnitDefinition.UnitType.SUPPORT: return "SUPPORT"
	return ""


func _type_accent(t: int) -> Color:
	return UITheme.VIOLET if t == UnitDefinition.UnitType.LONG else ACCENT


## Small pill outline (same gradient-border look as the rest of the theme,
## monochrome per-type rather than the shared cyan/violet blend) -- the
## reference mockup's "Tank" / "Ranged" / "Support" tag under each unit name.
func _build_type_pill(pos: Vector2, label_text: String, accent: Color) -> Control:
	var pill_size := Vector2(20.0 + label_text.length() * 8.0, 22.0)
	var pill := Control.new()
	pill.position = pos
	pill.size = pill_size
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var border := UITheme.build_gradient_panel(pill_size, 11.0, 1.5, false, accent, accent, 0.5)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(border)

	var lbl := Label.new()
	lbl.size = pill_size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", accent)
	lbl.text = label_text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)

	return pill


## A stat readout row (muted caption left, bold bright value right) --
## replaces the old single "320 HP  36 DPS  ..." line with a stacked column
## matching the reference mockup's per-stat rows.
func _add_stat_row(parent: Node, x: float, y: float, width: float, caption: String, value: String) -> void:
	var caption_label := Label.new()
	caption_label.position = Vector2(x, y)
	caption_label.size = Vector2(width * 0.4, 26.0)
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_override("font", UITheme.BODY_FONT)
	caption_label.add_theme_font_size_override("font_size", 13)
	caption_label.add_theme_color_override("font_color", MUTED_TEXT)
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.text = caption
	parent.add_child(caption_label)

	var value_label := Label.new()
	value_label.position = Vector2(x + width * 0.4, y)
	value_label.size = Vector2(width * 0.6, 26.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	value_label.add_theme_font_size_override("font_size", 16)
	value_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = value
	parent.add_child(value_label)


## Procedural checkmark badge (same "shape built in code, no glyph" approach
## as UITheme.build_diamond() -- a Unicode checkmark risks a tofu box on some
## Android font fallbacks) for a picked card, replacing the earlier
## dim-only feedback with the reference mockup's actual checkmark.
func _build_checkmark(size: float) -> Control:
	var c := Control.new()
	c.size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := Panel.new()
	bg.size = Vector2(size, size)
	bg.add_theme_stylebox_override("panel", _rounded_style(Color(0.1, 0.3, 0.19), READY_GREEN, 2, int(size * 0.5)))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)

	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.75, 1.0, 0.85)
	line.add_point(Vector2(size * 0.22, size * 0.52))
	line.add_point(Vector2(size * 0.42, size * 0.72))
	line.add_point(Vector2(size * 0.8, size * 0.26))
	c.add_child(line)

	return c


func _build_unit_cards() -> void:
	var y := 136.0 + SLOT_SIZE.y + 18.0
	var gap := 10.0
	var x := (VIEW_W - CARD_SIZE.x) * 0.5
	for unit_def in UnitDatabase.roster():
		var accent := _type_accent(unit_def.type)

		var card := Control.new()
		card.position = Vector2(x, y)
		card.size = CARD_SIZE
		add_child(card)

		var bg_panel := Panel.new()
		bg_panel.size = CARD_SIZE
		bg_panel.add_theme_stylebox_override("panel", _rounded_style(CARD_BG, Color.TRANSPARENT, 0, 18))
		bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg_panel)

		var border := UITheme.build_gradient_panel(CARD_SIZE, 18.0, 2.0, false, accent, accent.lightened(0.3), 0.7)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(border)

		var portrait_bg := Panel.new()
		portrait_bg.position = Vector2(16, (CARD_SIZE.y - PORTRAIT_SIZE.y) * 0.5)
		portrait_bg.size = PORTRAIT_SIZE
		portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_bg.add_theme_stylebox_override("panel", _rounded_style(Color(0.05, 0.06, 0.09), Color.TRANSPARENT, 0, 14))
		card.add_child(portrait_bg)

		var portrait := TextureRect.new()
		portrait.position = portrait_bg.position + Vector2(8, 8)
		portrait.size = PORTRAIT_SIZE - Vector2(16, 16)
		portrait.texture = unit_def.sprite
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		TeamColor.apply_vibrance_only(portrait)
		card.add_child(portrait)
		_card_portraits.append(portrait)
		_card_defs.append(unit_def)

		var blend := TextureRect.new()
		blend.position = Vector2.ZERO
		blend.size = portrait.size
		blend.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		blend.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		blend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blend.visible = false
		TeamColor.apply_vibrance_only(blend)
		portrait.add_child(blend)
		_card_blends.append(blend)

		var text_x := 16.0 + PORTRAIT_SIZE.x + 16.0
		var text_w := CARD_SIZE.x - text_x - STATS_COL_W - 16.0

		var name_label := Label.new()
		name_label.position = Vector2(text_x, 12)
		name_label.size = Vector2(text_w, 28)
		name_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = unit_def.display_name
		card.add_child(name_label)

		card.add_child(_build_type_pill(Vector2(text_x, 42), _type_label(unit_def.type), accent))

		var desc_label := Label.new()
		desc_label.position = Vector2(text_x, 68)
		desc_label.size = Vector2(text_w, 60)
		desc_label.add_theme_font_override("font", UITheme.BODY_FONT)
		desc_label.add_theme_font_size_override("font_size", 13)
		desc_label.add_theme_color_override("font_color", MUTED_TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.text = unit_def.description
		card.add_child(desc_label)

		var stats_x := CARD_SIZE.x - STATS_COL_W - 10.0
		_add_stat_row(card, stats_x, 12.0, STATS_COL_W, "HP", str(roundi(unit_def.hp)))
		_add_stat_row(card, stats_x, 42.0, STATS_COL_W, "DPS", str(roundi(unit_def.dps())))
		_add_stat_row(card, stats_x, 72.0, STATS_COL_W, "SPD", "%.1f" % unit_def.move_speed)
		_add_stat_row(card, stats_x, 102.0, STATS_COL_W, "RNG", "%.1f" % unit_def.preferred_range)

		var check := _build_checkmark(30.0)
		check.position = Vector2(CARD_SIZE.x - 44.0, 10.0)
		check.visible = false
		card.add_child(check)
		_unit_card_checks.append(check)

		var button := Button.new()
		button.size = CARD_SIZE
		button.flat = true
		button.modulate.a = 0.0
		button.pressed.connect(_on_unit_picked.bind(unit_def))
		card.add_child(button)

		_unit_card_containers.append(card)
		_unit_card_buttons.append(button)
		y += CARD_SIZE.y + gap


func _build_actions() -> void:
	var y := 136.0 + SLOT_SIZE.y + 18.0 + UnitDatabase.roster().size() * (CARD_SIZE.y + 10.0) + 14.0

	_clear_button = Button.new()
	_clear_button.text = "CLEAR"
	_clear_button.position = Vector2(VIEW_W * 0.5 - 220.0, y)
	_clear_button.size = Vector2(200.0, 60.0)
	_clear_button.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_clear_button.add_theme_font_size_override("font_size", 17)
	_clear_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.2, 0.08, 0.09), Color(0.8, 0.3, 0.3), 2, 14))
	_clear_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.26, 0.1, 0.11), Color(0.9, 0.35, 0.35), 2, 14))
	_clear_button.add_theme_stylebox_override("disabled", _rounded_style(Color(0.12, 0.12, 0.14), Color(0.3, 0.3, 0.32), 2, 14))
	_clear_button.pressed.connect(_on_clear_pressed)
	add_child(_clear_button)

	var ready := UITheme.build_gradient_button("READY", Vector2(200.0, 60.0))
	ready["container"].position = Vector2(VIEW_W * 0.5 + 20.0, y)
	add_child(ready["container"])
	_ready_button = ready["button"]
	_ready_button.pressed.connect(_on_ready_pressed)


func _on_unit_picked(unit_def: UnitDefinition) -> void:
	if _hand.size() >= UnitDatabase.HAND_SIZE or _hand.has(unit_def):
		return
	_hand.append(unit_def)
	_refresh()


func _on_clear_pressed() -> void:
	_hand.clear()
	_refresh()


func _on_ready_pressed() -> void:
	if _hand.size() != UnitDatabase.HAND_SIZE:
		return
	_draft_finished = true
	_go_to_deploy()


## Fires when DRAFT_TIME_LIMIT runs out with the hand still incomplete --
## fills whatever's left with random UNDRAFTED types (never a duplicate,
## same one-of-each-type rule the manual picks follow) and proceeds exactly
## like a manual READY press. Not a punishment: the player still gets a
## legal, playable hand, just not one they chose slot-by-slot.
func _auto_finish_draft() -> void:
	_draft_finished = true
	var pool := UnitDatabase.roster().filter(func(d: UnitDefinition) -> bool: return not _hand.has(d))
	pool.shuffle()
	while _hand.size() < UnitDatabase.HAND_SIZE and not pool.is_empty():
		_hand.append(pool.pop_back())
	_refresh()
	_go_to_deploy()


## Hands the 4 drafted types to deploy_screen.tscn (2026-09-11) rather than
## starting the match directly -- the player now chooses their own round-1
## composition (any multiset of the 4, e.g. 2 Enforcers + 2 Troopers) there
## instead of always getting exactly one of each.
func _go_to_deploy() -> void:
	GameState.player_drafted_types = _hand.duplicate()
	get_tree().change_scene_to_file("res://scenes/deploy_screen.tscn")


func _refresh() -> void:
	for i in range(UnitDatabase.HAND_SIZE):
		var bg_panel := _slot_bg_panels[i]
		var portrait := _slot_portraits[i]
		var label := _slot_labels[i]
		var plus := _slot_plus[i]
		if i < _hand.size():
			var unit_def := _hand[i]
			# A brighter tint instead of a stylebox swap -- the painted
			# panel (UITheme.build_painted_panel) has no stylebox to
			# override, so "filled" now reads as a lit-up glass tint.
			bg_panel.self_modulate = Color(1.25, 1.3, 1.35)
			portrait.texture = unit_def.sprite
			portrait.visible = true
			plus.visible = false
			label.text = unit_def.display_name.to_upper()
			label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		else:
			bg_panel.self_modulate = Color(1, 1, 1)
			portrait.visible = false
			plus.visible = true
			label.text = "SLOT %d" % (i + 1)
			label.add_theme_color_override("font_color", MUTED_TEXT)

	var roster := UnitDatabase.roster()
	for i in range(_unit_card_buttons.size()):
		var already_picked := _hand.has(roster[i])
		_unit_card_buttons[i].disabled = already_picked
		_unit_card_containers[i].modulate = Color(1, 1, 1, 0.45) if already_picked else Color(1, 1, 1, 1)
		_unit_card_checks[i].visible = already_picked

	var full := _hand.size() == UnitDatabase.HAND_SIZE
	_ready_button.disabled = not full
	_ready_button.get_parent().modulate.a = 1.0 if full else 0.45
	_clear_button.disabled = _hand.is_empty()
