extends Node2D
## Draft screen: tap a unit card to fill the next hand slot. Duplicates are
## allowed (2026-09-07, explicit reversal of a 2026-08-26 restriction that
## forced 4 distinct types) -- the earlier rule existed because an
## all-one-type hand was "trivially over-powerable before a single
## duplicate/level-up growth pick even happened," which is still a real risk
## re-opened by this change; a heavily duplicate-loaded starting hand is
## genuinely untested balance territory now, not verified safe. "Ready"
## unlocks once all HAND_SIZE slots are full, then hands off to
## GameState.start_match() -> scenes/match.tscn.
##
## Visual language borrows from Draft Showdown's real draft/deck screens
## (researched via actual screenshots+trailer frames earlier this project,
## not guessed): bold rounded cards, a colored accent per card, the unit's
## own portrait art front and center, chunky readable stat rows. Built with
## code-constructed Control nodes + StyleBoxFlat (no new art assets needed
## for the chrome itself -- just the unit portraits we already have).

const TeamColor := preload("res://scripts/team_color.gd")

const VIEW_W := 720.0
const VIEW_H := 1280.0

## Brightened 2026-09-06, same values as main_menu.gd/heroes_screen.gd -- see
## main_menu.gd's comment on why.
const BG_COLOR := Color(0.09, 0.08, 0.17)
const CARD_BG := Color(0.16, 0.16, 0.27)
const CARD_BG_FILLED := Color(0.12, 0.26, 0.32)
const ACCENT := Color(0.3, 0.92, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)
const MUTED_TEXT := Color(0.7, 0.74, 0.82)

const SLOT_SIZE := Vector2(150.0, 150.0)
const CARD_SIZE := Vector2(660.0, 158.0)
const PORTRAIT_SIZE := Vector2(120.0, 120.0)

var _hand: Array[UnitDefinition] = []
var _slot_panels: Array[Panel] = []
var _slot_portraits: Array[TextureRect] = []
var _slot_blends: Array[TextureRect] = []
var _slot_labels: Array[Label] = []
var _unit_cards: Array[Button] = []
var _card_count_badges: Array[Label] = []
var _card_portraits: Array[TextureRect] = []
var _card_blends: Array[TextureRect] = []
var _card_defs: Array[UnitDefinition] = []
var _ready_button: Button
var _clear_button: Button
var _breathe_phase: float = 0.0

const BREATHE_PERIOD := 1.8

## A generous soft timer, not a punishing one -- there's no real opponent
## waiting on you (see game_state.gd's doc comment, every match is vs a bot),
## so this exists purely for pace/tension, the same reason drafting games
## conventionally have one, not because anything is actually blocked on it.
## Timing out doesn't cost anything beyond losing the choice: it just
## auto-fills whatever's left with random undrafted types and proceeds,
## the same as a player who was indecisive and ran out of picks.
const DRAFT_TIME_LIMIT := 30.0
var _time_remaining: float = DRAFT_TIME_LIMIT
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
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35) if secs <= 5 else Color(0.95, 0.96, 1.0))
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
	portrait.texture = frames[idx]
	blend.texture = frames[next_idx]
	blend.modulate.a = frac
	blend.visible = true


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	var title := Label.new()
	title.position = Vector2(0, 26)
	title.size = Vector2(VIEW_W, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	title.text = "DRAFT YOUR SQUAD"
	add_child(title)

	var mode_label := Label.new()
	mode_label.position = Vector2(0, 60)
	mode_label.size = Vector2(VIEW_W, 22)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.add_theme_font_size_override("font_size", 14)
	mode_label.add_theme_color_override("font_color", ACCENT if GameState.ranked else GOLD)
	mode_label.text = "RANKED MATCH" if GameState.ranked else "CASUAL MATCH"
	add_child(mode_label)

	# Drafting is a sub-flow of the main menu now, not the app's front door,
	# so it needs a way back out. (The old HEROES shortcut that lived here
	# moved to the main menu, which is where it belongs.)
	var back_button := Button.new()
	back_button.text = "← BACK"
	back_button.position = Vector2(20.0, 30.0)
	back_button.size = Vector2(110.0, 36.0)
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.14, 0.16, 0.23), MUTED_TEXT, 2, 12))
	back_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.17, 0.19, 0.27), Color(0.8, 0.83, 0.9), 2, 12))
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back_button)

	_timer_label = Label.new()
	_timer_label.position = Vector2(VIEW_W - 130.0, 30.0)
	_timer_label.size = Vector2(110.0, 36.0)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 20)
	add_child(_timer_label)

	_build_slots()
	_build_unit_cards()
	_build_actions()
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


func _build_slots() -> void:
	var gap := 12.0
	var total_w := UnitDatabase.HAND_SIZE * SLOT_SIZE.x + (UnitDatabase.HAND_SIZE - 1) * gap
	var start_x := (VIEW_W - total_w) * 0.5
	var y := 84.0
	for i in range(UnitDatabase.HAND_SIZE):
		var pos := Vector2(start_x + i * (SLOT_SIZE.x + gap), y)

		var panel := Panel.new()
		panel.position = pos
		panel.size = SLOT_SIZE
		panel.add_theme_stylebox_override("panel", _rounded_style(CARD_BG, ACCENT, 0, 14))
		add_child(panel)

		var portrait := TextureRect.new()
		portrait.position = pos + Vector2(15, 8)
		portrait.size = SLOT_SIZE - Vector2(30, 44)
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
		label.position = pos + Vector2(0, SLOT_SIZE.y - 34)
		label.size = Vector2(SLOT_SIZE.x, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", MUTED_TEXT)
		label.text = "Slot %d" % (i + 1)
		add_child(label)

		_slot_panels.append(panel)
		_slot_portraits.append(portrait)
		_slot_blends.append(blend)
		_slot_labels.append(label)


func _build_unit_cards() -> void:
	var y := 84.0 + SLOT_SIZE.y + 26.0
	var gap := 14.0
	var x := (VIEW_W - CARD_SIZE.x) * 0.5
	for unit_def in UnitDatabase.roster():
		var card := Button.new()
		card.position = Vector2(x, y)
		card.size = CARD_SIZE
		card.flat = true
		card.add_theme_stylebox_override("normal", _rounded_style(CARD_BG, GOLD, 0))
		var hover := _rounded_style(CARD_BG, GOLD, 2)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.pressed.connect(_on_unit_picked.bind(unit_def))
		add_child(card)

		var portrait_bg := Panel.new()
		portrait_bg.position = Vector2(18, (CARD_SIZE.y - PORTRAIT_SIZE.y) * 0.5)
		portrait_bg.size = PORTRAIT_SIZE
		portrait_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_bg.add_theme_stylebox_override("panel", _rounded_style(Color(0.05, 0.06, 0.09), Color.TRANSPARENT, 0, 12))
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

		var text_x := 18.0 + PORTRAIT_SIZE.x + 16.0
		var name_label := Label.new()
		name_label.position = Vector2(text_x, 14)
		name_label.size = Vector2(CARD_SIZE.x - text_x - 14, 32)
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.text = unit_def.display_name
		card.add_child(name_label)

		var desc_label := Label.new()
		desc_label.position = Vector2(text_x, 46)
		desc_label.size = Vector2(CARD_SIZE.x - text_x - 14, 62)
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", MUTED_TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.text = unit_def.description
		card.add_child(desc_label)

		var stat_label := Label.new()
		stat_label.position = Vector2(text_x, CARD_SIZE.y - 34)
		stat_label.size = Vector2(CARD_SIZE.x - text_x - 14, 26)
		stat_label.add_theme_font_size_override("font_size", 15)
		stat_label.add_theme_color_override("font_color", ACCENT)
		stat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_label.text = "%d HP   %d DPS   %.1f m/s   %.1fm range" % [
			roundi(unit_def.hp), roundi(unit_def.dps()), unit_def.move_speed, unit_def.preferred_range]
		card.add_child(stat_label)

		# Duplicates are allowed now (2026-09-07) -- this badge is the only
		# feedback that you already have some of this type, since the card
		# itself no longer disables after one pick.
		var count_badge := Label.new()
		count_badge.position = Vector2(CARD_SIZE.x - 60.0, 10.0)
		count_badge.size = Vector2(46.0, 30.0)
		count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_badge.add_theme_font_size_override("font_size", 16)
		count_badge.add_theme_color_override("font_color", GOLD)
		count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_badge.visible = false
		card.add_child(count_badge)
		_card_count_badges.append(count_badge)

		_unit_cards.append(card)
		y += CARD_SIZE.y + gap


func _build_actions() -> void:
	var y := 84.0 + SLOT_SIZE.y + 26.0 + UnitDatabase.roster().size() * (CARD_SIZE.y + 14.0) + 10.0

	_clear_button = Button.new()
	_clear_button.text = "Clear"
	_clear_button.position = Vector2(VIEW_W * 0.5 - 220.0, y)
	_clear_button.size = Vector2(200.0, 64.0)
	_clear_button.add_theme_font_size_override("font_size", 18)
	_clear_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.2, 0.08, 0.09), Color(0.8, 0.3, 0.3), 2, 14))
	_clear_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.26, 0.1, 0.11), Color(0.9, 0.35, 0.35), 2, 14))
	_clear_button.add_theme_stylebox_override("disabled", _rounded_style(Color(0.12, 0.12, 0.14), Color(0.3, 0.3, 0.32), 2, 14))
	_clear_button.pressed.connect(_on_clear_pressed)
	add_child(_clear_button)

	_ready_button = Button.new()
	_ready_button.position = Vector2(VIEW_W * 0.5 + 20.0, y)
	_ready_button.size = Vector2(200.0, 64.0)
	_ready_button.add_theme_font_size_override("font_size", 18)
	_ready_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.09, 0.24, 0.14), Color(0.3, 0.85, 0.45), 2, 14))
	_ready_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.11, 0.3, 0.17), Color(0.4, 0.95, 0.55), 2, 14))
	_ready_button.add_theme_stylebox_override("disabled", _rounded_style(Color(0.12, 0.12, 0.14), Color(0.3, 0.3, 0.32), 2, 14))
	_ready_button.pressed.connect(_on_ready_pressed)
	add_child(_ready_button)


func _on_unit_picked(unit_def: UnitDefinition) -> void:
	if _hand.size() >= UnitDatabase.HAND_SIZE:
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
	GameState.start_match(_hand.duplicate())


## Fires when DRAFT_TIME_LIMIT runs out with the hand still incomplete --
## fills whatever's left with random types (duplicates allowed, same as a
## manual pick now can be -- see the 2026-09-07 doc comment at the top of
## this file) and proceeds exactly like a manual READY press. Not a
## punishment: the player still gets a legal, playable hand, just not one
## they chose slot-by-slot.
func _auto_finish_draft() -> void:
	_draft_finished = true
	var roster := UnitDatabase.roster()
	while _hand.size() < UnitDatabase.HAND_SIZE:
		_hand.append(roster[randi() % roster.size()])
	_refresh()
	GameState.start_match(_hand.duplicate())


func _refresh() -> void:
	for i in range(UnitDatabase.HAND_SIZE):
		var panel := _slot_panels[i]
		var portrait := _slot_portraits[i]
		var label := _slot_labels[i]
		if i < _hand.size():
			var unit_def := _hand[i]
			panel.add_theme_stylebox_override("panel", _rounded_style(CARD_BG_FILLED, ACCENT, 2, 14))
			portrait.texture = unit_def.sprite
			portrait.visible = true
			label.text = unit_def.display_name
			label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		else:
			panel.add_theme_stylebox_override("panel", _rounded_style(CARD_BG, ACCENT, 0, 14))
			portrait.visible = false
			label.text = "Slot %d" % (i + 1)
			label.add_theme_color_override("font_color", MUTED_TEXT)

	var roster := UnitDatabase.roster()
	var hand_full := _hand.size() >= UnitDatabase.HAND_SIZE
	for i in range(_unit_cards.size()):
		_unit_cards[i].disabled = hand_full
		_unit_cards[i].modulate = Color(1, 1, 1, 0.45) if hand_full else Color(1, 1, 1, 1)
		var count := 0
		for u in _hand:
			if u == roster[i]:
				count += 1
		var badge := _card_count_badges[i]
		badge.visible = count > 0
		if count > 0:
			badge.text = "x%d" % count

	var full := _hand.size() == UnitDatabase.HAND_SIZE
	_ready_button.disabled = not full
	_ready_button.text = "READY" if full else "Pick %d more" % (UnitDatabase.HAND_SIZE - _hand.size())
	_clear_button.disabled = _hand.is_empty()
