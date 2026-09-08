extends Node2D
## The game's actual front door. Until now draft_screen.tscn was the main
## scene, which is why the game appeared to have no menu -- it didn't. This
## takes that slot; drafting becomes a sub-flow reached via PLAY.
##
## Doubles as the retention surface: shows current arena + a progress bar
## toward the next one (see arena_database.gd), so there's always a visible
## "almost there" on the first screen you see.
##
## Same code-built-Control visual language as draft_screen.gd/heroes_screen.gd.

const TeamColor := preload("res://scripts/team_color.gd")

const VIEW_W := 720.0
const VIEW_H := 1280.0

## Brightened 2026-09-06 -- the original near-black/muted set read as
## "dirt-like and boring" next to something like Draft Showdown's bright
## palette. Lifted background/card tones + punchier accents, same "shared by
## convention" values across main_menu/heroes/draft (see those files).
const BG_COLOR := Color(0.09, 0.08, 0.17)
const CARD_BG := Color(0.16, 0.16, 0.27)
const ACCENT := Color(0.3, 0.92, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)
const MUTED_TEXT := Color(0.7, 0.74, 0.82)

const DAILY_REWARD := 75

var _currency_label: Label
var _daily_button: Button
var _title_label: Label
var _idle_phase: float = 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	# The current arena's own battlefield art as a dimmed backdrop -- ties the
	# menu to where you actually are on the ladder without needing separate
	# menu art per arena.
	var arena: Dictionary = PlayerProfile.current_arena()
	var backdrop := TextureRect.new()
	backdrop.texture = load(arena["floor"])
	backdrop.size = Vector2(VIEW_W, VIEW_H)
	backdrop.modulate = Color(1, 1, 1, 0.22)
	TeamColor.apply_vibrance_only(backdrop)
	add_child(backdrop)

	_build_header(arena)
	_build_arena_panel(arena)
	_build_buttons()
	_refresh()


## A barely-there title pulse -- the one piece of "the whole menu shouldn't
## be a still frame" that stays on THIS screen; the hero roster itself moved
## to its own Collection page (heroes_screen.gd) instead of living here.
func _process(delta: float) -> void:
	_idle_phase += delta
	if _title_label:
		var glow := 0.9 + sin(_idle_phase * 1.1) * 0.1
		_title_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0) * glow)


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


func _build_header(_arena: Dictionary) -> void:
	var title := Label.new()
	title.position = Vector2(0, 70)
	title.size = Vector2(VIEW_W, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	title.text = "CYBER DRAFT-DUEL"
	add_child(title)
	_title_label = title

	var subtitle := Label.new()
	subtitle.position = Vector2(0, 126)
	subtitle.size = Vector2(VIEW_W, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", MUTED_TEXT)
	subtitle.text = "Draft your squad. Watch them fight."
	add_child(subtitle)

	_currency_label = Label.new()
	_currency_label.position = Vector2(VIEW_W - 230.0, 24)
	_currency_label.size = Vector2(210.0, 30)
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_size_override("font_size", 20)
	_currency_label.add_theme_color_override("font_color", GOLD)
	add_child(_currency_label)


## The retention surface: which arena you're in, your rating, and how far
## you are from the next arena.
func _build_arena_panel(arena: Dictionary) -> void:
	var panel_pos := Vector2(30.0, 200.0)
	var panel_size := Vector2(VIEW_W - 60.0, 180.0)

	var panel := Panel.new()
	panel.position = panel_pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _rounded_style(CARD_BG, ACCENT, 2))
	add_child(panel)

	var arena_label := Label.new()
	arena_label.position = Vector2(0, 18)
	arena_label.size = Vector2(panel_size.x, 34)
	arena_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_label.add_theme_font_size_override("font_size", 26)
	arena_label.add_theme_color_override("font_color", ACCENT)
	arena_label.text = str(arena["name"])
	panel.add_child(arena_label)

	var rating_label := Label.new()
	rating_label.position = Vector2(0, 54)
	rating_label.size = Vector2(panel_size.x, 28)
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 18)
	rating_label.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	rating_label.text = "Rating %d" % PlayerProfile.rating
	panel.add_child(rating_label)

	# Progress bar toward the next arena.
	var bar_w := panel_size.x - 80.0
	var bar_pos := Vector2(40.0, 106.0)

	var bar_bg := ColorRect.new()
	bar_bg.position = bar_pos
	bar_bg.size = Vector2(bar_w, 16.0)
	bar_bg.color = Color(0.05, 0.06, 0.09, 0.9)
	panel.add_child(bar_bg)

	var progress := ArenaDatabase.progress_to_next(PlayerProfile.rating)
	var bar_fill := ColorRect.new()
	bar_fill.position = bar_pos
	bar_fill.size = Vector2(bar_w * progress, 16.0)
	bar_fill.color = ACCENT
	panel.add_child(bar_fill)

	var next_arena: Dictionary = ArenaDatabase.next_arena(PlayerProfile.rating)
	var next_label := Label.new()
	next_label.position = Vector2(0, 130)
	next_label.size = Vector2(panel_size.x, 26)
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 14)
	next_label.add_theme_color_override("font_color", MUTED_TEXT)
	if next_arena.is_empty():
		next_label.text = "Highest arena reached"
	else:
		var needed: int = int(next_arena["min_rating"]) - PlayerProfile.rating
		next_label.text = "%d rating to %s" % [maxi(needed, 0), str(next_arena["name"])]
	panel.add_child(next_label)


func _menu_button(text: String, y: float, bg: Color, border: Color, font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(VIEW_W * 0.5 - 200.0, y)
	b.size = Vector2(400.0, 74.0)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _rounded_style(bg, border, 2, 16))
	b.add_theme_stylebox_override("hover", _rounded_style(bg.lightened(0.08), border, 3, 16))
	b.add_theme_stylebox_override("disabled", _rounded_style(Color(0.12, 0.12, 0.14), Color(0.3, 0.3, 0.32), 2, 16))
	add_child(b)
	return b


func _build_buttons() -> void:
	# CASUAL/RANKED replace the single PLAY button (2026-09-06) -- casual is
	# quick, no-stakes matches (the "Searching for opponent" theater lives
	# there, see matchmaking_screen.gd), ranked is the honestly-framed solo
	# arena ladder with no fake opponent. Side by side so they read as the
	# two variants of one choice rather than two unrelated menu items.
	var half_w := 190.0
	var row_x := VIEW_W * 0.5 - half_w - 10.0

	var casual := Button.new()
	casual.text = "CASUAL"
	casual.position = Vector2(row_x, 440.0)
	casual.size = Vector2(half_w, 74.0)
	casual.add_theme_font_size_override("font_size", 22)
	casual.add_theme_stylebox_override("normal", _rounded_style(Color(0.09, 0.24, 0.14), Color(0.3, 0.85, 0.45), 2, 16))
	casual.add_theme_stylebox_override("hover", _rounded_style(Color(0.11, 0.3, 0.17), Color(0.4, 0.95, 0.55), 3, 16))
	casual.pressed.connect(func() -> void:
		GameState.ranked = false
		get_tree().change_scene_to_file("res://scenes/matchmaking_screen.tscn"))
	add_child(casual)

	var ranked := Button.new()
	ranked.text = "RANKED"
	ranked.position = Vector2(row_x + half_w + 20.0, 440.0)
	ranked.size = Vector2(half_w, 74.0)
	ranked.add_theme_font_size_override("font_size", 22)
	# Cyan accent, same as the arena panel above -- ties this button to the
	# ladder it actually leads to, and keeps GOLD reserved for HEROES/currency.
	ranked.add_theme_stylebox_override("normal", _rounded_style(Color(0.06, 0.16, 0.19), ACCENT, 2, 16))
	ranked.add_theme_stylebox_override("hover", _rounded_style(Color(0.08, 0.2, 0.24), ACCENT.lightened(0.1), 3, 16))
	ranked.pressed.connect(func() -> void:
		GameState.ranked = true
		get_tree().change_scene_to_file("res://scenes/draft_screen.tscn"))
	add_child(ranked)

	var heroes := _menu_button("HEROES", 534.0, Color(0.16, 0.13, 0.06), GOLD)
	heroes.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/heroes_screen.tscn"))

	# Rewarded-ad daily claim. Highest-converting rewarded placement pattern:
	# a free bonus the player opts into, never an interruption.
	_daily_button = _menu_button("", 628.0, Color(0.14, 0.09, 0.22), Color(0.65, 0.45, 0.95), 18)
	_daily_button.pressed.connect(_on_daily_pressed)

	var settings := _menu_button("SETTINGS", 722.0, Color(0.13, 0.15, 0.2), Color(0.5, 0.6, 0.7), 20)
	settings.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/settings_screen.tscn"))


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
		_daily_button.text = "▶  WATCH AD:  +%d BITS" % DAILY_REWARD
		_daily_button.disabled = false
	else:
		_daily_button.text = "DAILY BONUS CLAIMED"
		_daily_button.disabled = true
