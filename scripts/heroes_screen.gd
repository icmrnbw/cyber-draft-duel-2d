extends Node2D
## Out-of-match hero progression menu: spend PlayerProfile's persistent
## currency to unlock a unit TYPE's level-up tiers. NOT a starting-level
## boost (2026-08-26 redesign) -- every unit always starts a match at Lv.1.
## Unlocking a tier here only permits round_state.gd's roll_offers() to roll
## a "level up" card for that type during a match; it's the match itself
## that actually promotes a stack (see match_controller.gd's
## _unlocked_levels_by_path()). Only 2 tiers exist per type (Lv.2, then
## Lv.3, gated on RoundState.MAX_LEVEL=3) -- deliberately few and pricey so
## each is a substantial, curated jump rather than a long grindy ladder.
##
## Laid out as a collection-style grid (portrait, level badge, star pips,
## unlock button per card) rather than a plain list -- explicitly modeled on
## mobile collection screens (Draft Showdown's own Units/Collection tab) so
## a maxed-out roster reads as a "collection" worth screenshotting, the same
## instinct that drives r/DraftShowdown's build-showcase posts.
##
## Rebuilt 2026-09-10 in the UITheme neon language (see scripts/ui_theme.gd)
## -- this screen had only gotten the bottom tab bar in the first redesign
## pass, everything else (cards, badges, banner, fonts) was still the
## pre-redesign flat-accent style, which read as an unfinished "lazy" bolt-on
## next to the fully redesigned Main Menu/Battle HUD. Also drops the
## "[DEBUG] +1000 BITS" cheat button entirely (its own doc comment already
## said "remove before any real release build" -- this IS that removal).

const TeamColor := preload("res://scripts/team_color.gd")

const VIEW_W := 720.0
const VIEW_H := 1280.0

const CARD_BG := UITheme.CARD_BG
const GOLD := Color(1.0, 0.82, 0.3)
const MUTED_TEXT := UITheme.TEXT_MUTED
const MAXED_COLOR := Color(0.4, 0.95, 0.55)
const LOCKED_COLOR := Color(0.5, 0.53, 0.6)

const COLS := 2
const CARD_SIZE := Vector2(330.0, 300.0)
const CARD_GAP := 20.0
const GRID_TOP := 168.0
const PORTRAIT_SIZE := Vector2(200.0, 150.0)

var _currency_label: Label
var _collection_label: Label
var _portraits: Array[TextureRect] = []
var _portrait_blends: Array[TextureRect] = []
var _portrait_defs: Array[UnitDefinition] = []
var _level_badges: Array[Label] = []
var _star_labels: Array[Label] = []
var _detail_labels: Array[Label] = []
var _upgrade_buttons: Array[Button] = []
var _upgrade_containers: Array[Control] = []
var _breathe_phase: float = 0.0

## See draft_screen.gd's comment -- 1.8s read as "2fps," halved (2026-09-10).
const BREATHE_PERIOD := 0.9


## Real 4-frame breathing loop, same art and cadence as in-battle idle units
## (see UnitDefinition.idle_frames / match_controller.gd's _breathe_phase) --
## replaces an earlier version that just sine-scaled/rotated the flat static
## portrait in code, which wasn't a real animation and looked bad.
##
## Crossfades the upcoming frame in over an overlay TextureRect (same trick
## as match_controller.gd's idle_blend) instead of hard-swapping .texture --
## a plain swap every ~0.45s read as robotic/choppy, no transition at all
## between poses.
func _process(delta: float) -> void:
	_breathe_phase += delta
	for i in _portraits.size():
		var def := _portrait_defs[i]
		var level := PlayerProfile.max_unlocked_level(def)
		var frames := def.idle_frames_for_level(level)
		var blend := _portrait_blends[i]
		if frames.size() < 2:
			blend.visible = false
			continue
		var n := frames.size()
		var loop_t := fmod(_breathe_phase / BREATHE_PERIOD + float(i) * 0.27, 1.0) * n
		var idx := int(loop_t) % n
		var next_idx := (idx + 1) % n
		var frac: float = loop_t - float(int(loop_t))
		_portraits[i].texture = frames[idx]
		blend.texture = frames[next_idx]
		blend.modulate.a = frac
		blend.visible = true


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	# Same shared cyberpunk-city backdrop as the Main Menu/Draft screen
	# (assets/app_background.png, Meshy-generated 2026-09-10) -- one
	# consistent atmosphere across every menu-family screen, instead of the
	# old plain flat-color background here.
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/app_background.png")
	backdrop.size = Vector2(VIEW_W, VIEW_H)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(1, 1, 1, 0.5)
	add_child(backdrop)

	var title := Label.new()
	title.position = Vector2(0, 26)
	title.size = Vector2(VIEW_W, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.CYAN)
	title.text = "HEROES"
	add_child(title)

	_currency_label = Label.new()
	_currency_label.position = Vector2(VIEW_W - 220.0, 32)
	_currency_label.size = Vector2(200.0, 30)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_currency_label.add_theme_font_size_override("font_size", 17)
	_currency_label.add_theme_color_override("font_color", GOLD)
	add_child(_currency_label)

	_build_collection_banner()
	_build_hero_cards()
	_build_back_button()
	UITheme.build_tab_bar(self, VIEW_W, VIEW_H, UITheme.TAB_HEROES)
	_refresh()


## The "20/25"-style banner from the reference collection screen -- here it's
## "tiers unlocked" (each unit has 2 buyable tiers) rather than units owned,
## since every player already has the full 5-unit roster from the start.
func _build_collection_banner() -> void:
	var banner_w := VIEW_W - 60.0
	var banner_size := Vector2(banner_w, 44.0)
	var banner_pos := Vector2(30.0, 96.0)

	var bg_panel := Panel.new()
	bg_panel.position = banner_pos
	bg_panel.size = banner_size
	bg_panel.add_theme_stylebox_override("panel", _rounded_style(Color(0.16, 0.12, 0.04), Color.TRANSPARENT, 0, 22))
	add_child(bg_panel)

	var border := UITheme.build_gradient_panel(banner_size, 22.0, 2.0, false, GOLD, GOLD.lightened(0.3), 0.8)
	border.position = banner_pos
	add_child(border)

	_collection_label = Label.new()
	_collection_label.position = banner_pos
	_collection_label.size = banner_size
	_collection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_collection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collection_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_collection_label.add_theme_font_size_override("font_size", 17)
	_collection_label.add_theme_color_override("font_color", GOLD)
	add_child(_collection_label)


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


func _type_accent(t: int) -> Color:
	return UITheme.VIOLET if t == UnitDefinition.UnitType.LONG else UITheme.CYAN


func _build_hero_cards() -> void:
	var grid_w := CARD_SIZE.x * COLS + CARD_GAP * (COLS - 1)
	var grid_x := (VIEW_W - grid_w) * 0.5
	var roster := UnitDatabase.roster()

	for i in roster.size():
		var unit_def: UnitDefinition = roster[i]
		var accent := _type_accent(unit_def.type)
		var row := i / COLS
		var col := i % COLS
		# The roster doesn't evenly fill the grid (5 units, 2 columns) -- a
		# lone last-row card is centered instead of hugging the left column,
		# so the page doesn't end lopsided.
		var items_in_row: int = mini(COLS, roster.size() - row * COLS)
		var row_w := CARD_SIZE.x * items_in_row + CARD_GAP * (items_in_row - 1)
		var row_x := (VIEW_W - row_w) * 0.5
		var pos := Vector2(row_x + col * (CARD_SIZE.x + CARD_GAP), GRID_TOP + row * (CARD_SIZE.y + CARD_GAP))

		var card := Control.new()
		card.position = pos
		card.size = CARD_SIZE
		add_child(card)

		var bg_panel := Panel.new()
		bg_panel.size = CARD_SIZE
		bg_panel.add_theme_stylebox_override("panel", _rounded_style(CARD_BG, Color.TRANSPARENT, 0, 20))
		bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg_panel)

		var border := UITheme.build_gradient_panel(CARD_SIZE, 20.0, 2.0, false, accent, accent.lightened(0.3), 0.7)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(border)

		var portrait_bg := Panel.new()
		portrait_bg.position = Vector2((CARD_SIZE.x - PORTRAIT_SIZE.x) * 0.5, 12.0)
		portrait_bg.size = PORTRAIT_SIZE
		portrait_bg.add_theme_stylebox_override("panel", _rounded_style(Color(0.05, 0.06, 0.09), Color.TRANSPARENT, 0, 14))
		card.add_child(portrait_bg)

		var portrait := TextureRect.new()
		portrait.position = portrait_bg.position + Vector2(8, 8)
		portrait.size = PORTRAIT_SIZE - Vector2(16, 16)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		TeamColor.apply_vibrance_only(portrait)
		card.add_child(portrait)
		_portraits.append(portrait)
		_portrait_defs.append(unit_def)

		var portrait_blend := TextureRect.new()
		portrait_blend.position = portrait.position
		portrait_blend.size = portrait.size
		portrait_blend.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait_blend.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_blend.visible = false
		TeamColor.apply_vibrance_only(portrait_blend)
		card.add_child(portrait_blend)
		_portrait_blends.append(portrait_blend)

		# Level badge, corner-pinned on the portrait -- now a hex badge
		# (UITheme.build_hex_badge) instead of the old plain rounded square.
		var badge := UITheme.build_hex_badge("1", 19.0)
		badge.position = Vector2(6.0, 6.0)
		card.add_child(badge)
		_level_badges.append(badge.get_child(3) as Label)

		var name_label := Label.new()
		name_label.position = Vector2(0, 168.0)
		name_label.size = Vector2(CARD_SIZE.x, 28)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
		name_label.text = unit_def.display_name
		card.add_child(name_label)

		var star_label := Label.new()
		star_label.position = Vector2(0, 196.0)
		star_label.size = Vector2(CARD_SIZE.x, 22)
		star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_label.add_theme_font_override("font", UITheme.BODY_FONT)
		star_label.add_theme_font_size_override("font_size", 15)
		card.add_child(star_label)
		_star_labels.append(star_label)

		var detail_label := Label.new()
		detail_label.position = Vector2(14.0, 220.0)
		detail_label.size = Vector2(CARD_SIZE.x - 28.0, 20)
		detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_label.add_theme_font_override("font", UITheme.BODY_FONT)
		detail_label.add_theme_font_size_override("font_size", 12)
		detail_label.add_theme_color_override("font_color", MUTED_TEXT)
		card.add_child(detail_label)
		_detail_labels.append(detail_label)

		var upgrade_container := Control.new()
		upgrade_container.position = Vector2(25.0, 244.0)
		upgrade_container.size = Vector2(CARD_SIZE.x - 50.0, 46.0)
		card.add_child(upgrade_container)

		var upgrade_button := Button.new()
		upgrade_button.size = upgrade_container.size
		upgrade_button.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
		upgrade_button.add_theme_font_size_override("font_size", 13)
		upgrade_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		upgrade_button.pressed.connect(_on_upgrade_pressed.bind(unit_def))
		upgrade_container.add_child(upgrade_button)
		_upgrade_buttons.append(upgrade_button)
		_upgrade_containers.append(upgrade_container)


func _build_back_button() -> void:
	var back := Button.new()
	back.text = "BACK"
	back.position = Vector2(VIEW_W * 0.5 - 100.0, VIEW_H - 190.0)
	back.size = Vector2(200.0, 60.0)
	back.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_stylebox_override("normal", _rounded_style(Color(0.14, 0.16, 0.23), MUTED_TEXT, 2, 14))
	back.add_theme_stylebox_override("hover", _rounded_style(Color(0.17, 0.19, 0.27), Color(0.8, 0.83, 0.9), 2, 14))
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(back)


func _on_upgrade_pressed(unit_def: UnitDefinition) -> void:
	PlayerProfile.unlock_next_tier(unit_def)
	_refresh()


func _refresh() -> void:
	_currency_label.text = "%d BITS" % PlayerProfile.currency

	var roster := UnitDatabase.roster()
	var tiers_unlocked := 0
	var tiers_total := roster.size() * PlayerProfile.MAX_TIERS

	for i in range(roster.size()):
		var unit_def: UnitDefinition = roster[i]
		var tier := PlayerProfile.unlocked_tier(unit_def)
		var max_level := PlayerProfile.max_unlocked_level(unit_def)
		var fully_unlocked := tier >= PlayerProfile.MAX_TIERS
		tiers_unlocked += tier

		_portraits[i].texture = unit_def.idle_sprite_for_level(max_level)
		_level_badges[i].text = "%d" % max_level

		_star_labels[i].text = "★".repeat(max_level) + "☆".repeat(RoundState.MAX_LEVEL - max_level)
		_star_labels[i].add_theme_color_override("font_color", GOLD if tier > 0 else MUTED_TEXT)

		if tier == 0:
			_detail_labels[i].text = "Stays Lv.1 in matches"
		else:
			_detail_labels[i].text = "Lv.%d level-up available" % max_level

		var button := _upgrade_buttons[i]
		var container := _upgrade_containers[i]
		if fully_unlocked:
			button.text = "FULLY UNLOCKED"
			button.disabled = true
			button.add_theme_stylebox_override("normal", _rounded_style(Color(0.1, 0.16, 0.11), MAXED_COLOR, 2, 14))
			button.add_theme_stylebox_override("disabled", _rounded_style(Color(0.1, 0.16, 0.11), MAXED_COLOR, 2, 14))
			container.modulate.a = 1.0
		else:
			var cost := PlayerProfile.next_tier_cost(unit_def)
			var affordable := PlayerProfile.currency >= cost
			button.text = "UNLOCK Lv.%d — %d Bits" % [max_level + 1, cost]
			button.disabled = not affordable
			var accent := GOLD if affordable else LOCKED_COLOR
			button.add_theme_stylebox_override("normal", _rounded_style(Color(0.16, 0.13, 0.06), accent, 2, 14))
			button.add_theme_stylebox_override("hover", _rounded_style(Color(0.2, 0.16, 0.07), accent, 2, 14))
			button.add_theme_stylebox_override("disabled", _rounded_style(Color(0.12, 0.12, 0.14), LOCKED_COLOR, 2, 14))
			container.modulate.a = 1.0 if affordable else 0.7

	_collection_label.text = "TIERS UNLOCKED   %d / %d" % [tiers_unlocked, tiers_total]
