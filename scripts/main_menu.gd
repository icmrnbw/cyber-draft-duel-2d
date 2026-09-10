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
var _title_label: Label
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
	if _title_label:
		var glow := 0.85 + sin(_idle_phase * 1.1) * 0.15
		_title_label.add_theme_color_override("font_color", UITheme.CYAN * glow + Color(0, 0, 0, 1) * (1.0 - glow))


func _build_header() -> void:
	var title := Label.new()
	title.position = Vector2(0, 50)
	title.size = Vector2(VIEW_W, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UITheme.CYAN)
	title.text = "CYBER DRAFT-DUEL"
	add_child(title)
	_title_label = title

	var subtitle := Label.new()
	subtitle.position = Vector2(0, 106)
	subtitle.size = Vector2(VIEW_W, 26)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", UITheme.BODY_FONT)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	subtitle.text = "DRAFT / BATTLE / CLIMB"
	add_child(subtitle)

	# Currency pill, top-right -- gradient-bordered like the reference's
	# "1,250" badge rather than a plain label.
	var pill_size := Vector2(150.0, 40.0)
	var pill := UITheme.build_gradient_panel(pill_size, pill_size.y * 0.5, 2.0)
	pill.position = Vector2(VIEW_W - pill_size.x - 20.0, 20.0)
	add_child(pill)

	var diamond := UITheme.build_diamond(7.0, UITheme.CYAN)
	diamond.position = Vector2(24.0, pill_size.y * 0.5)
	pill.add_child(diamond)

	_currency_label = Label.new()
	_currency_label.position = Vector2(20.0, 0)
	_currency_label.size = Vector2(pill_size.x - 30.0, pill_size.y)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_currency_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_currency_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_currency_label.add_theme_font_size_override("font_size", 16)
	_currency_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	pill.add_child(_currency_label)


## The retention surface: which arena you're in, your rating, and how far
## you are from the next arena. Now a glowing gradient-bordered "season
## panel," same information as before.
func _build_arena_panel(arena: Dictionary) -> void:
	var panel_pos := Vector2(30.0, 150.0)
	var panel_size := Vector2(VIEW_W - 60.0, 170.0)

	var panel := UITheme.build_gradient_panel(panel_size, 20.0, 2.0)
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


func _build_buttons() -> void:
	# CASUAL/RANKED side by side, same split as before -- casual is quick,
	# no-stakes matches (the "Searching for opponent" theater lives there,
	# see matchmaking_screen.gd), ranked is the honestly-framed solo arena
	# ladder with no fake opponent.
	var half_w := 335.0
	var btn_h := 76.0
	var row_y := 360.0

	var casual := UITheme.build_gradient_button("CASUAL", Vector2(half_w, btn_h))
	casual["container"].position = Vector2(30.0, row_y)
	add_child(casual["container"])
	casual["button"].pressed.connect(func() -> void:
		GameState.ranked = false
		get_tree().change_scene_to_file("res://scenes/matchmaking_screen.tscn"))

	var ranked := UITheme.build_gradient_button("RANKED", Vector2(half_w, btn_h))
	ranked["container"].position = Vector2(30.0 + half_w + 20.0, row_y)
	add_child(ranked["container"])
	ranked["button"].pressed.connect(func() -> void:
		GameState.ranked = true
		get_tree().change_scene_to_file("res://scenes/draft_screen.tscn"))

	# Rewarded-ad daily claim, kept as its own row below -- highest-converting
	# rewarded placement pattern: a free bonus the player opts into, never
	# an interruption.
	var daily := UITheme.build_gradient_button("", Vector2(VIEW_W - 60.0, btn_h))
	daily["container"].position = Vector2(30.0, row_y + btn_h + 20.0)
	add_child(daily["container"])
	daily["button"].pressed.connect(_on_daily_pressed)
	_daily_button = daily["button"]
	_daily_container = daily["container"]


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
	var daily_label: Label = _daily_container.get_child(1)
	if PlayerProfile.can_claim_daily():
		daily_label.text = "▶  WATCH AD: +%d BITS" % DAILY_REWARD
		_daily_button.disabled = false
		_daily_container.modulate.a = 1.0
	else:
		daily_label.text = "DAILY BONUS CLAIMED"
		_daily_button.disabled = true
		_daily_container.modulate.a = 0.55
