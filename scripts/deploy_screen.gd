extends Node2D
## Squad deployment (2026-09-11, new): the player drafted 4 DISTINCT types on
## draft_screen.gd, but now chooses their own round-1 COMPOSITION from those
## 4 -- any multiset totaling exactly 4 units (e.g. 2 Enforcers + 2 Troopers,
## or 4 of the same type), not automatically one of each. See
## RoundState.init_with_deployment() for how the deployed squad and the
## drafted-type pool (still all 4, regardless of what's deployed) stay
## separate for the rest of the match's growth offers.
##
## Same visual language as draft_screen.gd/main_menu.gd (UITheme painted
## panels, hex badges, procedural breathing portraits) so this reads as one
## more step of the same flow, not a bolted-on extra screen.

const TeamColor := preload("res://scripts/team_color.gd")

const VIEW_W := 720.0
const VIEW_H := 1280.0
const SQUAD_SIZE := 4

const TILE_SIZE := Vector2(322.0, 260.0)
const GRID_GAP := 16.0
const GRID_TOP := 160.0
const PORTRAIT_SIZE := Vector2(96.0, 96.0)

## Same soft-timer convention as draft_screen.gd -- never blocks; auto-fills
## one of each drafted type (today's old default composition) if the player
## doesn't finish in time.
const DEPLOY_TIME_LIMIT := 24.0
var _time_remaining: float = DEPLOY_TIME_LIMIT
var _timer_hex: Control
var _timer_label: Label
var _deploy_finished := false

var _drafted_types: Array[UnitDefinition] = []
var _counts: Array[int] = []

var _portraits: Array[TextureRect] = []
var _portrait_blends: Array[TextureRect] = []
var _count_labels: Array[Label] = []
var _minus_buttons: Array[Button] = []
var _plus_buttons: Array[Button] = []
var _total_label: Label
var _ready_button: Button
var _ready_container: Control
var _breathe_phase: float = 0.0
const BREATHE_PERIOD := 0.9


func _ready() -> void:
	_drafted_types = GameState.player_drafted_types.duplicate()
	if _drafted_types.is_empty():
		_drafted_types = UnitDatabase.roster().slice(0, UnitDatabase.HAND_SIZE)
	for i in _drafted_types.size():
		_counts.append(0)

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

	_build_header()
	_build_tiles()
	_build_footer()
	UITheme.build_tab_bar(self, VIEW_W, VIEW_H, UITheme.TAB_HOME)
	_refresh()


func _process(delta: float) -> void:
	_breathe_phase += delta
	for i in _portraits.size():
		_animate_portrait(_portraits[i], _portrait_blends[i], _drafted_types[i], i)

	if _deploy_finished:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	var secs := int(ceil(_time_remaining))
	_timer_label.text = "0:%02d" % secs
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35) if secs <= 5 else UITheme.TEXT_BRIGHT)
	if _time_remaining <= 0.0:
		_auto_finish_deploy()


## Same crossfade-breathing trick as draft_screen.gd's _animate_portrait().
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
	var blend_alpha := clampf((frac - 0.35) / 0.3, 0.0, 1.0)
	portrait.texture = frames[idx]
	blend.texture = frames[next_idx]
	blend.modulate.a = blend_alpha
	blend.visible = true


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
	var back_button := Button.new()
	back_button.text = "← BACK"
	back_button.position = Vector2(20.0, 18.0)
	back_button.size = Vector2(96.0, 34.0)
	back_button.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	back_button.add_theme_font_size_override("font_size", 13)
	back_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.14, 0.16, 0.23), UITheme.TEXT_MUTED, 2, 12))
	back_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.17, 0.19, 0.27), Color(0.8, 0.83, 0.9), 2, 12))
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back_button)

	_timer_hex = UITheme.build_hex_badge("0:24", 26.0)
	_timer_hex.position = Vector2(VIEW_W - _timer_hex.size.x - 20.0, 12.0)
	add_child(_timer_hex)
	_timer_label = _timer_hex.get_child(3) as Label
	_timer_label.add_theme_font_size_override("font_size", 15)

	var title := Label.new()
	title.position = Vector2(0, 58)
	title.size = Vector2(VIEW_W, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UITheme.CYAN)
	title.text = "DEPLOY YOUR SQUAD"
	add_child(title)

	var subtitle := Label.new()
	subtitle.position = Vector2(0, 98)
	subtitle.size = Vector2(VIEW_W, 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UITheme.BODY_FONT)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	subtitle.text = "Choose any mix of your 4 drafted types — up to %d total" % SQUAD_SIZE
	add_child(subtitle)


func _type_accent(t: int) -> Color:
	return UITheme.VIOLET if t == UnitDefinition.UnitType.LONG else UITheme.CYAN


func _build_tiles() -> void:
	var cols := 2
	var grid_w := TILE_SIZE.x * cols + GRID_GAP * (cols - 1)
	var grid_x := (VIEW_W - grid_w) * 0.5

	for i in _drafted_types.size():
		var unit_def := _drafted_types[i]
		var accent := _type_accent(unit_def.type)
		var row := i / cols
		var col := i % cols
		var pos := Vector2(grid_x + col * (TILE_SIZE.x + GRID_GAP), GRID_TOP + row * (TILE_SIZE.y + GRID_GAP))

		var tile := Control.new()
		tile.position = pos
		tile.size = TILE_SIZE
		add_child(tile)

		var panel := UITheme.build_painted_panel(TILE_SIZE)
		tile.add_child(panel)

		var portrait_bg := Panel.new()
		portrait_bg.position = Vector2((TILE_SIZE.x - PORTRAIT_SIZE.x) * 0.5, 14.0)
		portrait_bg.size = PORTRAIT_SIZE
		portrait_bg.add_theme_stylebox_override("panel", _rounded_style(Color(0.05, 0.06, 0.09), Color.TRANSPARENT, 0, 14))
		tile.add_child(portrait_bg)

		var portrait := TextureRect.new()
		portrait.position = portrait_bg.position + Vector2(6, 6)
		portrait.size = PORTRAIT_SIZE - Vector2(12, 12)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		TeamColor.apply_vibrance_only(portrait)
		tile.add_child(portrait)
		_portraits.append(portrait)

		var blend := TextureRect.new()
		blend.size = portrait.size
		blend.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		blend.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		blend.visible = false
		TeamColor.apply_vibrance_only(blend)
		portrait.add_child(blend)
		_portrait_blends.append(blend)

		var name_label := Label.new()
		name_label.position = Vector2(0, 116.0)
		name_label.size = Vector2(TILE_SIZE.x, 26)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		name_label.text = unit_def.display_name
		tile.add_child(name_label)

		# Stepper row: [-] count [+], centered.
		var step_y := 154.0
		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.position = Vector2(TILE_SIZE.x * 0.5 - 70.0, step_y)
		minus_btn.size = Vector2(44.0, 44.0)
		minus_btn.add_theme_font_override("font", UITheme.HEADER_FONT)
		minus_btn.add_theme_font_size_override("font_size", 20)
		minus_btn.add_theme_stylebox_override("normal", _rounded_style(Color(0.16, 0.16, 0.27), accent, 2, 12))
		minus_btn.add_theme_stylebox_override("disabled", _rounded_style(Color(0.1, 0.1, 0.14), UITheme.TEXT_MUTED, 2, 12))
		minus_btn.pressed.connect(_on_step.bind(i, -1))
		tile.add_child(minus_btn)
		_minus_buttons.append(minus_btn)

		var count_label := Label.new()
		count_label.position = Vector2(TILE_SIZE.x * 0.5 - 20.0, step_y)
		count_label.size = Vector2(40.0, 44.0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Rajdhani, not Orbitron -- Orbitron's stylized zero has a diagonal
		# slash through it (to distinguish it from the letter O), which at
		# this size reads more like a "prohibited" icon than the digit 0,
		# confirmed by screenshotting a zero count and confusing myself.
		count_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		count_label.add_theme_font_size_override("font_size", 24)
		count_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		tile.add_child(count_label)
		_count_labels.append(count_label)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.position = Vector2(TILE_SIZE.x * 0.5 + 26.0, step_y)
		plus_btn.size = Vector2(44.0, 44.0)
		plus_btn.add_theme_font_override("font", UITheme.HEADER_FONT)
		plus_btn.add_theme_font_size_override("font_size", 20)
		plus_btn.add_theme_stylebox_override("normal", _rounded_style(Color(0.16, 0.16, 0.27), accent, 2, 12))
		plus_btn.add_theme_stylebox_override("disabled", _rounded_style(Color(0.1, 0.1, 0.14), UITheme.TEXT_MUTED, 2, 12))
		plus_btn.pressed.connect(_on_step.bind(i, 1))
		tile.add_child(plus_btn)
		_plus_buttons.append(plus_btn)

		var type_label := Label.new()
		type_label.position = Vector2(0, 210.0)
		type_label.size = Vector2(TILE_SIZE.x, 20)
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_override("font", UITheme.BODY_FONT)
		type_label.add_theme_font_size_override("font_size", 11)
		type_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		type_label.text = unit_def.description
		type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tile.add_child(type_label)


func _build_footer() -> void:
	var y := GRID_TOP + 2 * (TILE_SIZE.y + GRID_GAP) + 10.0

	_total_label = Label.new()
	_total_label.position = Vector2(0, y)
	_total_label.size = Vector2(VIEW_W, 30)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_total_label.add_theme_font_size_override("font_size", 18)
	_total_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	add_child(_total_label)

	var ready := UITheme.build_gradient_button("DEPLOY", Vector2(VIEW_W - 60.0, 70.0))
	ready["container"].position = Vector2(30.0, y + 40.0)
	add_child(ready["container"])
	_ready_button = ready["button"]
	_ready_container = ready["container"]
	_ready_button.pressed.connect(_on_deploy_pressed)


func _total_deployed() -> int:
	var total := 0
	for c in _counts:
		total += c
	return total


func _on_step(index: int, delta: int) -> void:
	var total := _total_deployed()
	var new_count: int = _counts[index] + delta
	if new_count < 0:
		return
	if delta > 0 and total >= SQUAD_SIZE:
		return
	_counts[index] = new_count
	_refresh()


func _build_deployed_squad() -> Array[UnitDefinition]:
	var squad: Array[UnitDefinition] = []
	for i in _drafted_types.size():
		for n in _counts[i]:
			squad.append(_drafted_types[i])
	return squad


func _on_deploy_pressed() -> void:
	if _total_deployed() != SQUAD_SIZE:
		return
	_deploy_finished = true
	GameState.start_match(_build_deployed_squad(), _drafted_types.duplicate())


## Same "never block the player" fallback as draft_screen.gd's own timeout --
## defaults to one of each drafted type, the exact composition every match
## used before this screen existed.
func _auto_finish_deploy() -> void:
	_deploy_finished = true
	for i in _counts.size():
		_counts[i] = 1
	GameState.start_match(_build_deployed_squad(), _drafted_types.duplicate())


func _refresh() -> void:
	var total := _total_deployed()
	for i in _counts.size():
		_count_labels[i].text = str(_counts[i])
		_minus_buttons[i].disabled = _counts[i] <= 0
		_plus_buttons[i].disabled = total >= SQUAD_SIZE

	_total_label.text = "%d / %d DEPLOYED" % [total, SQUAD_SIZE]
	_total_label.add_theme_color_override("font_color", UITheme.CYAN if total == SQUAD_SIZE else UITheme.TEXT_MUTED)

	var full := total == SQUAD_SIZE
	_ready_button.disabled = not full
	_ready_container.modulate.a = 1.0 if full else 0.45
