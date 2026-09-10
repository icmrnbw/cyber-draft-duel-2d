extends Node2D
## The game's actual front door. Rebuilt 2026-09-10 in the new neon
## cyberpunk visual language (see scripts/ui_theme.gd) -- a user-provided
## mobile UI mockup, matched for visual likeness only; every mechanic here
## (casual/ranked split, arena ladder, daily ad) is unchanged from before.

const VIEW_W := 720.0
const VIEW_H := 1280.0
const DAILY_REWARD := 75

var _currency_label: Label
var _daily_button: Button
var _daily_container: Control
var _daily_sub_label: Label
var _title_label: Label
var _title2_label: Label
var _idle_phase: float = 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	var arena: Dictionary = PlayerProfile.current_arena()

	# Shared cyberpunk-city backdrop (assets/app_background.png, Meshy-
	# generated 2026-09-10), same as Heroes/Settings/Draft -- replaces the
	# previous misuse of the in-battle arena FLOOR texture (a tileable
	# top-down pixel-art tile meant to sit under battle sprites) stretched
	# full-screen as menu wallpaper. That texture's flat retro pixel style
	# directly clashed with this screen's smooth vector/neon chrome and was
	# the single biggest "doesn't look like the reference" offender -- a
	# menu backdrop needed its own art, not a repurposed gameplay asset.
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/app_background.png")
	backdrop.size = Vector2(VIEW_W, VIEW_H)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(1, 1, 1, 0.5)
	add_child(backdrop)

	_build_header()
	_build_arena_panel(arena)
	_build_buttons()
	UITheme.build_tab_bar(self, VIEW_W, VIEW_H, UITheme.TAB_HOME)
	_refresh()


## A barely-there title pulse -- the one piece of "the whole menu shouldn't
## be a still frame" that stays on THIS screen; the hero roster itself lives
## on the Collection page (heroes_screen.gd) instead.
func _process(delta: float) -> void:
	_idle_phase += delta
	if _title2_label:
		var glow := 0.85 + sin(_idle_phase * 1.1) * 0.15
		_title2_label.add_theme_color_override("font_color", UITheme.CYAN * glow + Color(0, 0, 0, 1) * (1.0 - glow))


## Compact 2-line logo lockup, top-left -- the reference's home screen keeps
## the big brand moment for the splash screen only and uses a small logo
## mark here instead; matched now that scripts/splash_screen.gd exists.
func _build_header() -> void:
	var title := Label.new()
	title.position = Vector2(24, 22)
	title.size = Vector2(220, 26)
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	title.text = "CYBER"
	add_child(title)
	_title_label = title

	var title2 := Label.new()
	title2.position = Vector2(24, 42)
	title2.size = Vector2(220, 30)
	title2.add_theme_font_override("font", UITheme.HEADER_FONT)
	title2.add_theme_font_size_override("font_size", 19)
	title2.add_theme_color_override("font_color", UITheme.CYAN)
	title2.text = "DRAFT-DUEL"
	add_child(title2)
	_title2_label = title2

	# Gear icon, top-right -- direct settings access from Home, same as the
	# reference's header icon row (its bell has no feature behind it here,
	# so it's left out rather than shipping a dead tap target).
	var gear_btn := Button.new()
	gear_btn.position = Vector2(VIEW_W - 46.0, 20.0)
	gear_btn.size = Vector2(36.0, 36.0)
	gear_btn.flat = true
	gear_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	gear_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	gear_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/settings_screen.tscn"))
	add_child(gear_btn)
	var gear_icon := UITheme.build_icon_gear(26.0, UITheme.TEXT_MUTED)
	gear_icon.position = Vector2(5.0, 5.0)
	gear_btn.add_child(gear_icon)

	# Currency pill, left of the gear icon -- gradient-bordered like the
	# reference's "1,250" badge rather than a plain label.
	var pill_size := Vector2(140.0, 36.0)
	var pill := UITheme.build_gradient_panel(pill_size, pill_size.y * 0.5, 2.0)
	pill.position = Vector2(VIEW_W - pill_size.x - 56.0, 20.0)
	add_child(pill)

	var diamond := UITheme.build_diamond(6.0, UITheme.CYAN)
	diamond.position = Vector2(22.0, pill_size.y * 0.5)
	pill.add_child(diamond)

	_currency_label = Label.new()
	_currency_label.position = Vector2(18.0, 0)
	_currency_label.size = Vector2(pill_size.x - 26.0, pill_size.y)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_currency_label.add_theme_font_size_override("font_size", 15)
	_currency_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	pill.add_child(_currency_label)


## The retention surface: which arena you're in, your rating, and how far
## you are from the next arena. Painted-glass "season panel" (real Meshy art
## via UITheme.build_painted_panel, 2026-09-10) instead of the flatter
## procedural gradient-shader panel, same information as before.
func _build_arena_panel(arena: Dictionary) -> void:
	var panel_pos := Vector2(30.0, 150.0)
	var panel_size := Vector2(VIEW_W - 60.0, 170.0)

	var panel := UITheme.build_painted_panel(panel_size)
	panel.position = panel_pos
	add_child(panel)

	var arena_label := Label.new()
	arena_label.position = Vector2(0, 18)
	arena_label.size = Vector2(panel_size.x, 34)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_label.add_theme_font_override("font", UITheme.HEADER_FONT)
	arena_label.add_theme_font_size_override("font_size", 20)
	arena_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	arena_label.text = str(arena["name"]).to_upper()
	panel.add_child(arena_label)

	var rating_label := Label.new()
	rating_label.position = Vector2(0, 54)
	rating_label.size = Vector2(panel_size.x, 28)
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_override("font", UITheme.BODY_FONT)
	rating_label.add_theme_font_size_override("font_size", 17)
	rating_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	rating_label.text = "RATING %d" % PlayerProfile.rating
	panel.add_child(rating_label)

	# Progress bar toward the next arena.
	var bar_w := panel_size.x - 80.0
	var bar_pos := Vector2(40.0, 100.0)

	var bar_bg := ColorRect.new()
	bar_bg.position = bar_pos
	bar_bg.size = Vector2(bar_w, 14.0)
	bar_bg.color = Color(0.03, 0.03, 0.07, 0.9)
	panel.add_child(bar_bg)

	var progress := ArenaDatabase.progress_to_next(PlayerProfile.rating)
	if progress > 0.0:
		var fill_size := Vector2(bar_w * progress, 14.0)
		var bar_fill := UITheme.build_gradient_panel(fill_size, 7.0, 0.0, true)
		bar_fill.position = bar_pos
		panel.add_child(bar_fill)

	var next_arena: Dictionary = ArenaDatabase.next_arena(PlayerProfile.rating)
	var next_label := Label.new()
	next_label.position = Vector2(0, 124)
	next_label.size = Vector2(panel_size.x, 26)
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_override("font", UITheme.BODY_FONT)
	next_label.add_theme_font_size_override("font_size", 13)
	next_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	if next_arena.is_empty():
		next_label.text = "HIGHEST ARENA REACHED"
	else:
		var needed: int = int(next_arena["min_rating"]) - PlayerProfile.rating
		next_label.text = "%d RATING TO %s" % [maxi(needed, 0), str(next_arena["name"]).to_upper()]
	panel.add_child(next_label)


## One icon-tile in the 2x2 action grid -- icon on top, title + subtitle
## below, matching the reference mockup's PLAY/DECKS/MISSIONS/SHOP tiles
## (icon+title+subtitle) instead of the earlier flat single-line buttons.
func _build_tile(pos: Vector2, size: Vector2, icon: Control, title: String, subtitle: String, on_press: Callable) -> Dictionary:
	var tile := Control.new()
	tile.position = pos
	tile.size = size
	add_child(tile)

	var panel := UITheme.build_painted_panel(size)
	tile.add_child(panel)

	icon.position = Vector2((size.x - icon.size.x) * 0.5, 20.0)
	tile.add_child(icon)

	var title_label := Label.new()
	title_label.position = Vector2(0, 68.0)
	title_label.size = Vector2(size.x, 26)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UITheme.HEADER_FONT)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	title_label.text = title
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(title_label)

	var sub_label := Label.new()
	sub_label.position = Vector2(0, 96.0)
	sub_label.size = Vector2(size.x, 22)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_override("font", UITheme.BODY_FONT)
	sub_label.add_theme_font_size_override("font_size", 12)
	sub_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	sub_label.text = subtitle
	sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(sub_label)

	var button := Button.new()
	button.size = size
	button.flat = true
	button.modulate.a = 0.0
	button.pressed.connect(on_press)
	tile.add_child(button)

	return {"tile": tile, "sub_label": sub_label, "button": button}


## 2x2 icon-tile grid -- CASUAL/RANKED (the same split as before: casual is
## quick, no-stakes matches, the "Searching for opponent" theater lives in
## matchmaking_screen.gd; ranked is the honestly-framed solo arena ladder
## with no fake opponent) plus HEROES (the reference's "Decks: Build & Edit"
## slot, our real collection/progression screen) and DAILY BONUS (its
## "Shop" slot repurposed for the one monetization surface this project
## actually has -- there's no real-money shop to put there instead).
func _build_buttons() -> void:
	var gap := 16.0
	var tile_w := (VIEW_W - 60.0 - gap) * 0.5
	var tile_h := 150.0
	var row_y := 360.0
	var col_x := [30.0, 30.0 + tile_w + gap]

	_build_tile(Vector2(col_x[0], row_y), Vector2(tile_w, tile_h),
		UITheme.build_icon_swords(38.0, UITheme.CYAN), "CASUAL", "Find a Match",
		func() -> void:
			GameState.ranked = false
			get_tree().change_scene_to_file("res://scenes/matchmaking_screen.tscn"))

	_build_tile(Vector2(col_x[1], row_y), Vector2(tile_w, tile_h),
		UITheme.build_icon_trophy(38.0, UITheme.VIOLET), "RANKED", "Climb the Ladder",
		func() -> void:
			GameState.ranked = true
			get_tree().change_scene_to_file("res://scenes/draft_screen.tscn"))

	_build_tile(Vector2(col_x[0], row_y + tile_h + gap), Vector2(tile_w, tile_h),
		UITheme.build_icon_cards(38.0, UITheme.CYAN), "HEROES", "Build & Upgrade",
		func() -> void: get_tree().change_scene_to_file("res://scenes/heroes_screen.tscn"))

	var daily := _build_tile(Vector2(col_x[1], row_y + tile_h + gap), Vector2(tile_w, tile_h),
		UITheme.build_icon_gift(38.0, UITheme.VIOLET), "DAILY BONUS", "", _on_daily_pressed)
	_daily_button = daily["button"]
	_daily_container = daily["tile"]
	_daily_sub_label = daily["sub_label"]


func _on_daily_pressed() -> void:
	if not PlayerProfile.can_claim_daily():
		return
	# AdService fires the reward callback itself (immediately while ads are
	# stubbed, after a real rewarded video once an ad SDK is wired in) -- the
	# claim must NOT happen here, or a cancelled ad would still pay out.
	AdService.show_rewarded(func() -> void:
		PlayerProfile.claim_daily(DAILY_REWARD)
		_refresh()
	)


func _refresh() -> void:
	_currency_label.text = "%d BITS" % PlayerProfile.currency
	if PlayerProfile.can_claim_daily():
		_daily_sub_label.text = "Watch Ad: +%d Bits" % DAILY_REWARD
		_daily_button.disabled = false
		_daily_container.modulate.a = 1.0
	else:
		_daily_sub_label.text = "Claimed Today"
		_daily_button.disabled = true
		_daily_container.modulate.a = 0.55
