extends Node2D
## The full match loop, ported from the 3D game's game_manager.gd +
## battle_controller.gd + battle_hud.gd growth-pick flow (see round_state.gd for
## the ported lives/growth data layer). One difference from the 3D version:
## that split existed for its Node/scene architecture; here it's folded into a
## single script, matching this project's existing single-script-per-scene style.
##
## Loop: BattleSim plays one round -> RoundState records the result -> on a
## draw, replay the same round with a fresh seed; otherwise the bot's side
## auto-grows and the human picks their own growth offers (this was the whole
## point of the 3D game's player-choice growth feature) -> next round -> until
## a side runs out of lives or MAX_ROUNDS is hit.

const TeamColor := preload("res://scripts/team_color.gd")
const SFX_SHOOT := preload("res://assets/sfx/shoot.wav")
const SFX_SWING := preload("res://assets/sfx/swing.wav")
const SFX_STRIKE := preload("res://assets/sfx/strike.wav")

const VIEW_W := 720.0
const VIEW_H := 1280.0
const LANE_WIDTH := 700.0
## Pushed down from 140 (2026-09-10) to make room for the taller top HUD
## (round badge + both squads' avatar/hearts rows) -- see _build_top_hud().
const LANE_TOP_Y := 195.0
const LANE_BOTTOM_Y := 1140.0
const HUMAN_SIDE := 0

## Brightened 2026-09-06, same values as main_menu.gd/heroes_screen.gd/
## draft_screen.gd -- see main_menu.gd's comment on why.
const GOLD := Color(1.0, 0.82, 0.3)
const MUTED_TEXT := Color(0.7, 0.74, 0.82)
## "Rival" HUD framing only (hearts, avatar border, label) -- actual combat
## identity (rim glow, HP bars) stays TeamColor.TEAM_B orange, unchanged.
## The reference mockup itself keeps enemy HP bars orange while using a
## separate magenta accent for the hearts/avatar chrome specifically, so
## this mirrors that rather than recoloring the whole enemy team.
const RIVAL_ACCENT := Color(0.85, 0.35, 0.75)

enum Phase { BATTLE, TRANSITION, GROWTH_PICK, MATCH_OVER }

signal growth_offer_picked(index: int)

var _round_state: RoundState
var _sim: BattleSim
var _accum := 0.0
var _idle_phase := 0.0
## Real time, not the sim-tick-scaled _idle_phase above (that one also drives
## stun-star spin) -- a dedicated clock for the 4-frame breathing loop so its
## cadence can be tuned independently. See UnitDefinition.idle_frames.
var _breathe_phase := 0.0
## See draft_screen.gd's comment -- 1.8s read as "2fps," halved (2026-09-10).
const BREATHE_PERIOD := 0.9
var _views: Array[Dictionary] = []
var _phase: Phase = Phase.BATTLE

var _result_label: Label
var _growth_title: Label
var _round_result_overlay: Control
var _round_result_title: Label
var _round_badge_label: Label
var _squad_hearts: Array[Dictionary] = []
var _rival_hearts: Array[Dictionary] = []
var _growth_buttons: Array[Button] = []
var _dim_overlay: ColorRect
var _forfeit_button: Button
var _forfeit_label: Label

## Sprite scale is a fixed constant, deliberately NOT roster-size-aware --
## an earlier version tapered it down as the roster grew round over round
## (sqrt(4/count), floored at 0.07 vs this 0.20 baseline) to fight overlap in
## crowded late rounds, but that read as units visibly shrinking every round
## and ending up too small, which the user explicitly rejected. Overlap in a
## crowded late round is the accepted tradeoff for units staying full, legible
## size throughout the match.
const REF_SCALE := 0.20
var _unit_scale := REF_SCALE


func _ready() -> void:
	_build_background()
	_result_label = _build_result_label()
	_growth_title = _build_growth_title()
	_dim_overlay = _build_dim_overlay()
	_round_result_overlay = _build_round_result_overlay()

	# Drafted by the player on draft_screen.gd, plus a random canned bot hand --
	# see GameState.start_match(). Falls back to a trooper-heavy default hand if
	# this scene is ever run directly (e.g. from the editor) without drafting
	# first. A mirror hand (identical composition both sides) is deliberately
	# avoided even in the fallback: with a single unit type, identical hands have
	# no source of randomness in combat and simultaneous-eliminate to an exact
	# draw on every seed forever -- confirmed via tools/round_smoke_test.gd.
	var hand_a: Array[UnitDefinition] = GameState.player_hand
	var hand_b: Array[UnitDefinition] = GameState.bot_hand
	var seed_value := GameState.match_seed
	if hand_a.is_empty() or hand_b.is_empty():
		var trooper: UnitDefinition = load("res://resources/trooper.tres")
		hand_a = [trooper, trooper, trooper, trooper]
		hand_b = [trooper, trooper, trooper]
		seed_value = 1

	_build_top_hud(hand_a[0], hand_b[0])

	# Every unit starts a match at level 1 regardless of Heroes-menu progress
	# -- PlayerProfile only gates which "level up" offers can appear DURING
	# the match (see _unlocked_levels_by_path()/_resolve_growth_picks()), it
	# never grants a head start.
	_round_state = RoundState.new()
	_round_state.init(hand_a, hand_b, seed_value)
	UITheme.build_tab_bar(self, VIEW_W, VIEW_H, UITheme.TAB_BATTLE, true)
	_start_round()


const ENERGY_LINE_SHADER := preload("res://shaders/energy_line.gdshader")

## Pixel-art asteroid floor (Meshy, plain crater texture with no baked
## platforms/lines -- those are drawn here instead so they can carry real
## team colors and animate) replaces the old flat ColorRect lane. The two
## spawn platforms sit at LANE_TOP_Y (opponent, team B) and LANE_BOTTOM_Y
## (player, team A), matching where each side's front line actually forms;
## the connecting beam cycles between both teams' colors via
## shaders/energy_line.gdshader rather than a static print. z_index left at
## the default (0, below everything else added after it) so units/UI still
## draw on top untouched.
func _build_background() -> void:
	# Which battlefield you fight on is your current ladder arena (see
	# arena_database.gd) rather than one fixed image -- climbing rating is
	# what changes the scenery, which is the visible half of the progression.
	var floor_art := TextureRect.new()
	floor_art.texture = load(PlayerProfile.current_arena()["floor"])
	floor_art.size = Vector2(VIEW_W, VIEW_H)
	TeamColor.apply_vibrance_only(floor_art)
	add_child(floor_art)

	var line := ColorRect.new()
	line.color = Color.WHITE
	line.size = Vector2(28.0, LANE_BOTTOM_Y - LANE_TOP_Y)
	line.position = Vector2(VIEW_W * 0.5 - 14.0, LANE_TOP_Y)
	var line_mat := ShaderMaterial.new()
	line_mat.shader = ENERGY_LINE_SHADER
	line_mat.set_shader_parameter("color_a", TeamColor.TEAM_A)
	line_mat.set_shader_parameter("color_b", TeamColor.TEAM_B)
	line.material = line_mat
	add_child(line)

	_build_spawn_ring(Vector2(VIEW_W * 0.5, LANE_TOP_Y), TeamColor.TEAM_B)
	_build_spawn_ring(Vector2(VIEW_W * 0.5, LANE_BOTTOM_Y), TeamColor.TEAM_A)


## One shared grayscale ring texture, tinted per side via `modulate` -- no
## separate art needed per team color, same trick TeamColor.apply() uses for
## unit rim-light. Nearest-filtered to stay crisp against the pixel-art floor.
func _build_spawn_ring(pos: Vector2, color: Color) -> void:
	var ring := TextureRect.new()
	ring.texture = load("res://assets/spawn_ring.png")
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.modulate = color
	var ring_size := 130.0
	ring.size = Vector2(ring_size, ring_size)
	ring.position = pos - Vector2(ring_size, ring_size) * 0.5
	add_child(ring)




func _build_result_label() -> Label:
	var label := Label.new()
	label.position = Vector2(0, VIEW_H * 0.5 - 60)
	label.size = Vector2(VIEW_W, 120)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.visible = false
	add_child(label)
	return label


func _build_growth_title() -> Label:
	var label := Label.new()
	label.position = Vector2(0, VIEW_H * 0.5 - 220)
	label.size = Vector2(VIEW_W, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.visible = false
	label.z_index = 5
	add_child(label)
	return label


## Shown behind the growth-pick cards so they read cleanly instead of
## colliding visually with the roster standing behind them. Deliberately
## light (was 0.88 -- near-opaque, which defeated the whole point of
## showing the roster during picks at all) so the actual army is still
## clearly readable through it, not just the cards floating in a black void.
func _build_dim_overlay() -> ColorRect:
	var rect := ColorRect.new()
	# Brightened 2026-09-06 (was near-black 0.02/0.02/0.04) -- a near-black
	# overlay was fighting the brighter roster underneath after the palette
	# pass, undoing exactly what that pass was for.
	rect.color = Color(0.08, 0.06, 0.16, 0.35)
	rect.size = Vector2(VIEW_W, VIEW_H)
	rect.z_index = 4
	rect.visible = false
	add_child(rect)
	return rect


## Parametric heart curve (16sin^3(t), 13cos(t)-5cos(2t)-2cos(3t)-cos(4t)),
## sampled and normalized -- same "no new art needed, build the shape in
## code" approach _build_star() already uses for the stun effect. Y is
## negated converting into it since the formula's "up" (lobes) is positive-Y
## in standard math convention, but Godot's 2D Y increases downward.
func _build_heart(color: Color, size: float) -> Polygon2D:
	var heart := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 24
	for i in range(segments):
		var t := (float(i) / float(segments)) * TAU
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		points.append(Vector2(x, -y) / 17.0 * size)
	heart.polygon = points
	heart.color = color
	return heart


const HEART_SIZE := 26.0
const LIFE_LOST_COLOR := Color(0.35, 0.37, 0.44, 0.55)
const LIFE_FULL_COLOR := Color(0.95, 0.25, 0.32)

## One heart "slot": a dim empty-heart shape always visible underneath, and a
## bright filled one on top that gets tweened away when that life is lost --
## avoids needing to swap the same polygon's color mid-animation. `fill_color`
## defaults to LIFE_FULL_COLOR (used by nothing anymore, kept as a sane
## fallback) -- real callers pass the squad's own accent (cyan for you,
## RIVAL_ACCENT for the opponent), matching the reference's per-side heart
## color instead of a single universal red.
func _build_heart_slot(parent: Node2D, pos: Vector2, size: float = HEART_SIZE, fill_color: Color = LIFE_FULL_COLOR, z: int = 0) -> Dictionary:
	var empty := _build_heart(LIFE_LOST_COLOR, size)
	empty.position = pos
	empty.z_index = z
	parent.add_child(empty)

	var filled := _build_heart(fill_color, size)
	filled.position = pos
	filled.z_index = z
	parent.add_child(filled)

	return {"filled": filled}


## Persistent top HUD: round hex badge (center), both squads' hex-framed
## avatar + label + hearts row (left = you, right = rival), and the LEAVE
## button. Replaces the old single-line "Round N -- Lives A: X Lives B: Y"
## text with the reference mockup's layout. Avatars use the actual drafted
## hand's first unit (free, ties the HUD to real roster content) rather
## than a generic silhouette icon this project doesn't have art for.
func _build_top_hud(player_avatar_def: UnitDefinition, rival_avatar_def: UnitDefinition) -> void:
	var leave_w := 116.0
	var leave_h := 40.0
	var leave_panel := UITheme.build_gradient_panel(Vector2(leave_w, leave_h), leave_h * 0.5, 2.0,
		false, RIVAL_ACCENT, RIVAL_ACCENT.darkened(0.25))
	leave_panel.position = Vector2(VIEW_W - leave_w - 16.0, 16.0)
	leave_panel.z_index = 10
	add_child(leave_panel)

	_forfeit_label = Label.new()
	_forfeit_label.size = Vector2(leave_w, leave_h)
	_forfeit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_forfeit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_forfeit_label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	_forfeit_label.add_theme_font_size_override("font_size", 15)
	_forfeit_label.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	_forfeit_label.text = "LEAVE"
	_forfeit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	leave_panel.add_child(_forfeit_label)

	_forfeit_button = Button.new()
	_forfeit_button.size = Vector2(leave_w, leave_h)
	_forfeit_button.flat = true
	_forfeit_button.modulate.a = 0.0
	_forfeit_button.pressed.connect(_on_forfeit_pressed)
	leave_panel.add_child(_forfeit_button)

	var round_badge := UITheme.build_hex_badge("1", 30.0)
	round_badge.position = Vector2(VIEW_W * 0.5 - round_badge.size.x * 0.5, 8.0)
	round_badge.z_index = 10
	add_child(round_badge)
	_round_badge_label = round_badge.get_child(3)  # outer, outer_line, inner_line, label

	_squad_hearts = _build_squad_row(Vector2(16.0, 88.0), "YOUR SQUAD", UITheme.CYAN, player_avatar_def)
	_rival_hearts = _build_squad_row(Vector2(VIEW_W - 260.0, 88.0), "RIVAL", RIVAL_ACCENT, rival_avatar_def)


func _build_squad_row(pos: Vector2, label_text: String, accent: Color, avatar_def: UnitDefinition) -> Array[Dictionary]:
	var avatar_size := 56.0
	var avatar_frame := UITheme.build_gradient_panel(Vector2(avatar_size, avatar_size), 14.0, 2.5,
		false, accent, accent.darkened(0.3))
	avatar_frame.position = pos
	avatar_frame.z_index = 10
	add_child(avatar_frame)

	var portrait := TextureRect.new()
	portrait.position = Vector2(6, 6)
	portrait.size = Vector2(avatar_size - 12.0, avatar_size - 12.0)
	portrait.texture = avatar_def.sprite
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	TeamColor.apply_vibrance_only(portrait)
	avatar_frame.add_child(portrait)

	var label_x := pos.x + avatar_size + 10.0
	var label := Label.new()
	label.position = Vector2(label_x, pos.y - 2.0)
	label.size = Vector2(180.0, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_override("font", UITheme.BODY_FONT_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", accent)
	label.z_index = 10
	label.text = label_text
	add_child(label)

	var hearts: Array[Dictionary] = []
	for i in RoundState.LIVES_PER_SIDE:
		var hpos := Vector2(label_x + i * 22.0, pos.y + 26.0)
		hearts.append(_build_heart_slot(self, hpos, 11.0, accent, 10))
	return hearts


## The Draft-Showdown-style "who won this round" screen (user reference:
## real screenshots of DS's own round-transition screen, hearts and all) --
## replaces a plain one-line text banner. Built once in _ready() and
## populated/animated fresh each round rather than rebuilt, so there's
## nothing to free/leak between rounds.
func _build_round_result_overlay() -> Control:
	var root := Control.new()
	root.z_index = 8
	root.visible = false
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.88)
	dim.size = Vector2(VIEW_W, VIEW_H)
	root.add_child(dim)

	# A gradient-bordered banner rather than plain text -- the closest
	# practical match to the reference's hex-cut glowing title card without
	# a full text-clip-path shader. Hearts/avatars live in the persistent
	# top HUD now (see _build_top_hud()), not duplicated here -- the break
	# animation plays on those same nodes directly.
	var banner_size := Vector2(580.0, 130.0)
	var banner := UITheme.build_gradient_panel(banner_size, 18.0, 2.5)
	banner.position = Vector2((VIEW_W - banner_size.x) * 0.5, VIEW_H * 0.5 - banner_size.y * 0.5)
	root.add_child(banner)

	var title := Label.new()
	title.position = Vector2(0, 0)
	title.size = banner_size
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.HEADER_FONT)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.TEXT_BRIGHT)
	banner.add_child(title)
	_round_result_title = title

	return root


## Plays the whole round-result beat: fade the overlay in, hold a moment,
## animate the heart that was just lost shrinking/spinning away (on the
## PERSISTENT top-HUD heart nodes -- they still show the pre-loss state
## here, since _update_top_hud() hasn't run for this round yet), hold again
## on the result, fade out, then refresh the top HUD to the new lives count.
## lives_*_before are captured by the caller BEFORE
## RoundState.record_round_result() decrements them, so there's an actual
## "before" state to animate away from.
func _show_round_result_screen(lives_a_before: int, lives_b_before: int) -> void:
	var lives_a_after := _round_state.lives_a
	var lives_b_after := _round_state.lives_b

	var human_won := _sim.result == (BattleSim.Result.TEAM_A if HUMAN_SIDE == 0 else BattleSim.Result.TEAM_B)
	_round_result_title.text = "ROUND %d\n%s" % [_round_state.round_number, "YOU WIN" if human_won else "YOU LOSE"]
	_round_result_title.add_theme_color_override("font_color", UITheme.CYAN if human_won else RIVAL_ACCENT)

	_round_result_overlay.modulate.a = 0.0
	_round_result_overlay.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(_round_result_overlay, "modulate:a", 1.0, 0.25)
	await fade_in.finished

	await get_tree().create_timer(0.45).timeout

	# Break the heart that was just lost, if any -- lives_before/after differ
	# by at most 1 per side per round (record_round_result only ever
	# decrements the LOSING side by one).
	if lives_b_before > lives_b_after:
		await _break_heart(_rival_hearts[lives_b_after]["filled"])
	if lives_a_before > lives_a_after:
		await _break_heart(_squad_hearts[lives_a_after]["filled"])

	await get_tree().create_timer(0.7).timeout

	var fade_out := create_tween()
	fade_out.tween_property(_round_result_overlay, "modulate:a", 0.0, 0.25)
	await fade_out.finished
	_round_result_overlay.visible = false
	_update_top_hud()


## A little punch-then-shrink-and-spin, not just an instant disappear --
## reads as the heart actually breaking rather than an item silently
## vanishing.
func _break_heart(heart: Polygon2D) -> void:
	var tw := create_tween()
	tw.tween_property(heart, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(heart, "rotation", deg_to_rad(200.0), 0.3)
	tw.parallel().tween_property(heart, "modulate:a", 0.0, 0.3)
	_play_sfx(SFX_STRIKE)
	await tw.finished


## Leaving mid-match always counts as a loss (see _show_match_result()'s
## `forfeited` param) -- otherwise it's a free way to dodge a match that's
## going badly, the actual problem this solves (not "does it look like a
## real opponent left," which a penalty alone doesn't demonstrate either
## way). Two-tap: the small top-corner button turns into a "confirm?" state
## on first tap so a stray touch mid-battle can't lose a match by accident.
var _forfeit_armed := false

func _on_forfeit_pressed() -> void:
	if not _forfeit_armed:
		_forfeit_armed = true
		_forfeit_label.text = "CONFIRM?"
		return
	_show_match_result(true)


## Updates the round hex badge + both squads' persistent heart rows to the
## CURRENT lives count -- called after a life is actually lost (the
## round-result screen's own break animation runs off the pre/post snapshot
## it's given directly, see _show_round_result_screen(), not off this).
func _update_top_hud() -> void:
	_round_badge_label.text = str(_round_state.round_number)
	for i in RoundState.LIVES_PER_SIDE:
		_squad_hearts[i]["filled"].visible = i < _round_state.lives_a
		_rival_hearts[i]["filled"].visible = i < _round_state.lives_b


# ---------------------------------------------------------------- round loop

func _free_views() -> void:
	for v in _views:
		v.sprite.queue_free()
		v.idle_blend.queue_free()
		v.ring.queue_free()
		v.hp_bg.queue_free()
		v.hp_fill.queue_free()
		v.stun_fx.queue_free()
	_views.clear()


## Builds a fresh BattleSim from the CURRENT roster and spawns real views for
## it, but never ticks it -- units just stand at their real spawn positions
## (exactly where the actual battle will start them). Shared by the real
## round start and the growth-pick preview (see _resolve_growth_picks())
## specifically so "what you see while picking" and "what round actually
## starts with" are backed by the identical spawn logic, not two separate
## approximations of it that could drift apart.
func _spawn_preview_views() -> void:
	_free_views()
	_sim = BattleSim.new()
	_sim.setup(_round_state.roster_a, _round_state.roster_b, _round_state.current_seed(),
		_round_state.power_a, _round_state.power_b, _round_state.levels_a, _round_state.levels_b)
	for u in _sim.units:
		_views.append(_build_unit_view(u))


func _start_round() -> void:
	_spawn_preview_views()
	_update_top_hud()
	_result_label.visible = false
	_phase = Phase.BATTLE


func _process(delta: float) -> void:
	if _phase == Phase.MATCH_OVER:
		return

	# Only BATTLE actually advances the sim -- TRANSITION (banner shown) and
	# GROWTH_PICK (picking, see _resolve_growth_picks()) both just keep
	# rendering whatever _views currently holds so the roster stays visible
	# and idly animated (not ticking) rather than a frozen screenshot.
	if _phase == Phase.BATTLE:
		# Cap how much a single slow frame can make up: if a frame stalls
		# (import hiccup, alt-tab, low-end device), an uncapped accumulator
		# would run a burst of ticks to "catch up" -- each producing its own
		# attack tweens -- so that slow frame gets slower still, and the game
		# never recovers. Capping means the sim can visibly run in slow
		# motion for a moment instead of spiraling.
		_accum = minf(_accum + delta, 8.0 * BattleSim.TICK_DELTA)
		while _accum >= BattleSim.TICK_DELTA:
			_accum -= BattleSim.TICK_DELTA
			_sim.tick()
			_consume_events()

	_idle_phase += delta * 2.0
	_breathe_phase += delta
	for v in _views:
		_update_view(v)

	if _phase == Phase.BATTLE and _sim.result != BattleSim.Result.IN_PROGRESS:
		_on_round_finished()


func _on_round_finished() -> void:
	_phase = Phase.TRANSITION

	# A drawn round replays the same round_number with a fresh seed and
	# never advances it on its own -- past MAX_DRAW_RETRIES, force a real
	# result from the last sim's own HP totals (same tiebreak BattleSim uses
	# internally for its 90s timeout) instead of replaying indefinitely. See
	# round_state.gd's doc comment on MAX_DRAW_RETRIES for why this exists.
	var result := _sim.result
	if result == BattleSim.Result.DRAW and _round_state.draw_retry >= RoundState.MAX_DRAW_RETRIES:
		var a_hp := _sim.total_hp(0)
		var b_hp := _sim.total_hp(1)
		if a_hp > b_hp:
			result = BattleSim.Result.TEAM_A
		elif b_hp > a_hp:
			result = BattleSim.Result.TEAM_B
		# else: still an exact tie even after HP tiebreak -- record_round_result()
		# below will treat DRAW as a loss for both, which is fine this rare.

	# Captured BEFORE record_round_result() decrements lives -- the animated
	# round-result screen needs the pre-loss count to actually show a heart
	# breaking, not just the already-updated total.
	var lives_a_before := _round_state.lives_a
	var lives_b_before := _round_state.lives_b
	_round_state.record_round_result(result)

	if result == BattleSim.Result.DRAW:
		_show_banner("DRAW — replaying round %d" % _round_state.round_number)
		await get_tree().create_timer(1.5).timeout
		_start_round()
		return

	# Played even on the match-deciding round, before _show_match_result() --
	# seeing the last heart break is the whole point, not something to skip
	# past straight to the match-over screen.
	await _show_round_result_screen(lives_a_before, lives_b_before)

	if _round_state.is_match_over():
		_show_match_result()
		return

	await _resolve_growth_picks()
	_round_state.advance_round_number()
	_start_round()


func _show_banner(text: String) -> void:
	_result_label.text = text
	_result_label.visible = true


const CURRENCY_WIN := 30
const CURRENCY_LOSS := 10


var _reward_label: Label
var _double_button: Button
var _earned_bits := 0
var _already_doubled := false


## `forfeited`: the human backed out mid-match (see _on_forfeit_pressed())
## instead of the sim reaching a real conclusion. Always scored as a loss --
## letting a forfeit dodge the loss consequence would make it a free way to
## avoid a bad outcome, the same reason a roguelike doesn't let you savescum
## out of a run that's going badly.
func _show_match_result(forfeited: bool = false) -> void:
	_phase = Phase.MATCH_OVER
	_forfeit_button.visible = false
	var winner := -1 if forfeited else _round_state.winner_team()
	var won := not forfeited and winner == HUMAN_SIDE
	var text := "DRAW"
	if forfeited:
		text = "MATCH FORFEITED"
	# Casual matches show the fake-but-harmless opponent name from the
	# matchmaking theater (see matchmaking_screen.gd) instead of "TEAM A/B" --
	# ranked never runs that screen, so it keeps the generic team wording.
	elif GameState.ranked:
		if winner == 0:
			text = "TEAM A WINS THE MATCH"
		elif winner == 1:
			text = "TEAM B WINS THE MATCH"
	else:
		var opp := GameState.casual_opponent_name
		if winner == HUMAN_SIDE:
			text = "YOU DEFEATED %s" % opp
		elif winner >= 0:
			text = "%s WINS" % opp
	_result_label.text = text
	_result_label.visible = true
	_update_top_hud()

	# Only the human side earns meta-progression -- the bot has no
	# PlayerProfile of its own. A draw (only reachable via the MAX_ROUNDS
	# safety cap) is treated as a loss for both currency and rating.
	_earned_bits = CURRENCY_WIN if won else CURRENCY_LOSS
	PlayerProfile.add_currency(_earned_bits)
	# Rating is a RANKED-only concept -- casual has nothing on the line, by
	# design (see game_state.gd's doc comment on `ranked`).
	var rating_delta := PlayerProfile.apply_match_result(won) if GameState.ranked else 0

	_build_reward_panel(rating_delta)
	_build_match_over_buttons()


## Post-match reward summary + the "double it" rewarded-ad offer. This is the
## highest-converting rewarded placement in the genre precisely because it
## amplifies a reward the player has ALREADY earned rather than gating
## anything behind a video.
func _build_reward_panel(rating_delta: int) -> void:
	var arena_name := str(PlayerProfile.current_arena()["name"])

	_reward_label = Label.new()
	_reward_label.position = Vector2(0, VIEW_H * 0.5 - 6.0)
	_reward_label.size = Vector2(VIEW_W, 90)
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_font_size_override("font_size", 19)
	_reward_label.add_theme_color_override("font_color", GOLD)
	_reward_label.z_index = 5
	add_child(_reward_label)
	_update_reward_label(rating_delta, arena_name)

	_double_button = Button.new()
	_double_button.text = "▶  WATCH AD:  DOUBLE BITS"
	_double_button.position = Vector2(VIEW_W * 0.5 - 200.0, VIEW_H * 0.5 + 170.0)
	_double_button.size = Vector2(400.0, 62.0)
	_double_button.z_index = 5
	_double_button.add_theme_font_size_override("font_size", 18)
	_double_button.add_theme_stylebox_override("normal", _rounded_style(Color(0.14, 0.09, 0.22), LEVEL_UP_ACCENT, 2, 14))
	_double_button.add_theme_stylebox_override("hover", _rounded_style(Color(0.18, 0.12, 0.28), LEVEL_UP_ACCENT, 3, 14))
	_double_button.add_theme_stylebox_override("disabled", _rounded_style(Color(0.12, 0.12, 0.14), Color(0.3, 0.3, 0.32), 2, 14))
	_double_button.pressed.connect(func() -> void: _on_double_pressed(rating_delta, arena_name))
	add_child(_double_button)


func _update_reward_label(rating_delta: int, arena_name: String) -> void:
	if not GameState.ranked:
		_reward_label.text = "+%d BITS\n(Casual match -- no rating change)" % _earned_bits
		return
	var sign_str := "+" if rating_delta >= 0 else ""
	_reward_label.text = "+%d BITS\nRating %s%d  →  %d  (%s)" % [
		_earned_bits, sign_str, rating_delta, PlayerProfile.rating, arena_name]


func _on_double_pressed(rating_delta: int, arena_name: String) -> void:
	if _already_doubled:
		return
	# The reward is granted inside AdService's callback, never here -- a
	# skipped/failed ad must pay nothing (see ad_service.gd).
	AdService.show_rewarded(func() -> void:
		_already_doubled = true
		PlayerProfile.add_currency(_earned_bits)
		_earned_bits *= 2
		_update_reward_label(rating_delta, arena_name)
		_double_button.text = "BITS DOUBLED!"
		_double_button.disabled = true
	)


## The match previously just... ended, with no way back in -- a real gap, not
## a style choice. Rematch redrafts a fresh bot hand + seed with the same
## drafted player hand (GameState.start_match() already does exactly this);
## Main Menu goes back to the draft screen to pick a new hand entirely.
func _build_match_over_buttons() -> void:
	var button_y := VIEW_H * 0.5 + 90.0

	var rematch := Button.new()
	rematch.text = "REMATCH"
	rematch.position = Vector2(VIEW_W * 0.5 - 220.0, button_y)
	rematch.size = Vector2(200.0, 64.0)
	rematch.z_index = 5
	rematch.add_theme_font_size_override("font_size", 18)
	rematch.add_theme_stylebox_override("normal", _rounded_style(Color(0.09, 0.24, 0.14), Color(0.3, 0.85, 0.45), 2, 14))
	rematch.add_theme_stylebox_override("hover", _rounded_style(Color(0.11, 0.3, 0.17), Color(0.4, 0.95, 0.55), 2, 14))
	rematch.pressed.connect(func() -> void: GameState.start_match(GameState.player_hand))
	add_child(rematch)

	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.position = Vector2(VIEW_W * 0.5 + 20.0, button_y)
	menu.size = Vector2(200.0, 64.0)
	menu.z_index = 5
	menu.add_theme_font_size_override("font_size", 18)
	menu.add_theme_stylebox_override("normal", _rounded_style(Color(0.13, 0.15, 0.2), Color(0.5, 0.6, 0.7), 2, 14))
	menu.add_theme_stylebox_override("hover", _rounded_style(Color(0.16, 0.18, 0.24), Color(0.6, 0.7, 0.8), 2, 14))
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	add_child(menu)


# ---------------------------------------------------------------- growth picks

## Bot side auto-grows (same random logic the 3D game always used); the human
## side walks through one show_growth_choice() per growth slot it's owed,
## applying each pick before rolling the next slot's offers -- so a later
## "double" offer reflects power a same-round earlier pick already added.
func _resolve_growth_picks() -> void:
	var bot_side := 1 - HUMAN_SIDE
	var human_lost: bool
	if HUMAN_SIDE == 0:
		human_lost = _round_state.last_round_result == BattleSim.Result.TEAM_B
	else:
		human_lost = _round_state.last_round_result == BattleSim.Result.TEAM_A

	_round_state.auto_grow_side(bot_side, not human_lost, _bot_difficulty_scale())
	var slots := _round_state.additions_for(human_lost)
	_dim_overlay.visible = slots > 0
	if slots > 0:
		# The just-ended round's units are still sitting wherever the battle
		# left them (scattered, some dead) -- swap to a real spawn-position
		# preview of the roster instead, so a duplicate/reinforce/level-up
		# decision isn't made blind against a frozen battle photo, and the
		# EFFECT of a pick (a new duplicate appearing, a unit's art jumping
		# to its next tier) is immediately visible on the actual army.
		_phase = Phase.GROWTH_PICK
		_spawn_preview_views()

	var unlocked := _unlocked_levels_by_path()
	for slot_i in range(slots):
		var offers := _round_state.roll_offers(HUMAN_SIDE, slot_i, unlocked)
		if offers.is_empty():
			continue
		var label := "Round %d — choose your upgrade (%d/%d)" % [_round_state.round_number, slot_i + 1, slots]
		var picked_i: int = await _show_growth_choice(offers, label)
		_round_state.apply_offer(HUMAN_SIDE, offers[picked_i])
		_spawn_preview_views()
	_dim_overlay.visible = false


## PlayerProfile only knows unit types the player has actually seen in a
## Heroes-menu context; type_pool_a is exactly the set that could ever appear
## in this match, so that's what gets looked up -- no need to touch the
## whole roster of possibly-duplicated instances.
func _unlocked_levels_by_path() -> Dictionary:
	var out := {}
	for def in _round_state.type_pool_a:
		out[def.resource_path] = PlayerProfile.max_unlocked_level(def)
	return out


## 0.0 (nothing unlocked) to 1.0 (every roster unit's tiers fully unlocked) --
## same "tiers unlocked / total possible" ratio heroes_screen.gd's collection
## banner shows the player, fed into auto_grow_side() so the bot compensates
## for its structural inability to level up (see round_state.gd's doc
## comment on BOT_MAX_GROWTH_MULT/BOT_MAX_DOUBLE_CHANCE) roughly in step with
## how much power the player has actually bought. Uses the whole roster, not
## just this match's 4 drafted types, so a player who's invested everywhere
## faces the tougher bot even in a match where their heaviest-invested unit
## didn't get drafted.
func _bot_difficulty_scale() -> float:
	var roster := UnitDatabase.roster()
	var total := 0
	for def in roster:
		total += PlayerProfile.unlocked_tier(def)
	var max_total := roster.size() * PlayerProfile.MAX_TIERS
	return float(total) / float(maxi(max_total, 1))


## Ephemeral AudioStreamPlayer, same fire-and-free pattern already used for
## impact-particle chips: spawn, play, queue_free on finish. Pitch is jittered
## slightly per-call so a burst of the same sound (e.g. 4 units firing at
## once) doesn't sound like one sample stacked -- cheap "sounds less robotic"
## trick, no extra assets needed.
func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not GameSettings.sfx_enabled:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.94, 1.06)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _rounded_style(bg_color: Color, border_color: Color, border_w: int = 0, radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.set_border_width_all(border_w)
		sb.border_color = border_color
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.4)
	return sb


## Rounded on the bottom two corners only, flat on top -- for a label plate
## that sits flush against the bottom edge of an already-rounded card
## (see _build_offer_card()) rather than floating as its own separate shape.
func _bottom_plate_style(bg_color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb


## Draft-Showdown-style pick card: a big character portrait floating on the
## card, a level badge and a count badge in the top corners (their "cost
## pips," repurposed since our picks have no currency cost), and a bold
## colored action plate across the bottom holding the title + detail text --
## replaces an earlier plainer version the user explicitly disliked next to
## Draft Showdown's own cards. Kept in our existing dark-card identity
## (brightened 2026-09-06) rather than copying DS's pastel backgrounds
## outright, which would clash with the rest of the app.
func _build_offer_card(pos: Vector2, size: Vector2, accent: Color, portrait: Texture2D,
		corner_badge: String, title: String, detail: String, on_press: Callable) -> Button:
	var card := Button.new()
	card.position = pos
	card.size = size
	card.z_index = 5
	card.flat = true
	card.add_theme_stylebox_override("normal", _rounded_style(Color(0.16, 0.16, 0.27), accent, 2, 20))
	card.add_theme_stylebox_override("hover", _rounded_style(Color(0.19, 0.19, 0.31), accent, 3, 20))
	card.add_theme_stylebox_override("pressed", _rounded_style(Color(0.19, 0.19, 0.31), accent, 3, 20))
	card.pressed.connect(on_press)
	add_child(card)

	var plate_h := 76.0

	var portrait_size := Vector2(size.x - 40.0, size.y - plate_h - 34.0)
	var portrait_rect := TextureRect.new()
	portrait_rect.position = Vector2((size.x - portrait_size.x) * 0.5, 14.0)
	portrait_rect.size = portrait_size
	portrait_rect.texture = portrait
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TeamColor.apply_vibrance_only(portrait_rect)
	card.add_child(portrait_rect)

	if corner_badge != "":
		var badge_size := Vector2(38.0, 38.0)
		var badge_bg := Panel.new()
		badge_bg.position = Vector2(8.0, 8.0)
		badge_bg.size = badge_size
		badge_bg.add_theme_stylebox_override("panel", _rounded_style(Color(0.08, 0.09, 0.13), accent, 2, 12))
		badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge_bg)

		var badge_label := Label.new()
		badge_label.position = Vector2.ZERO
		badge_label.size = badge_size
		badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge_label.add_theme_font_size_override("font_size", 15)
		badge_label.add_theme_color_override("font_color", accent)
		badge_label.text = corner_badge
		badge_bg.add_child(badge_label)

	# Bottom action plate -- the DS-style bright colored strip a title reads
	# off of, distinct from the rest of the (dark-mode) card.
	var plate := Panel.new()
	plate.position = Vector2(0, size.y - plate_h)
	plate.size = Vector2(size.x, plate_h)
	plate.add_theme_stylebox_override("panel", _bottom_plate_style(accent, 20))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(plate)

	var dark_text := Color(0.08, 0.08, 0.1)
	var title_label := Label.new()
	title_label.position = Vector2(6.0, 8.0)
	title_label.size = Vector2(size.x - 12.0, 28.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", dark_text)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.text = title
	plate.add_child(title_label)

	var detail_label := Label.new()
	detail_label.position = Vector2(6.0, 38.0)
	detail_label.size = Vector2(size.x - 12.0, 34.0)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.add_theme_color_override("font_color", dark_text.lightened(0.3))
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_label.text = detail
	plate.add_child(detail_label)

	return card


## DUPLICATE offers get a gold accent (a "rare upgrade" read, same visual
## language Draft Showdown's own deck screen uses for its highlighted cards --
## researched via real screenshots earlier this project) since doubling an
## existing (type, level) squad's count is the stronger, rarer-feeling pick;
## LEVEL UP gets violet (promotes that squad in place, no count change);
## REINFORCE gets a cooler blue since a fresh level-1 unit is the safest,
## most common pick.
const LEVEL_UP_ACCENT := Color(0.65, 0.45, 0.95)
const REINFORCE_ACCENT := Color(0.35, 0.85, 0.95)


func _show_growth_choice(offers: Array, label_text: String) -> int:
	_result_label.visible = false
	_growth_title.text = label_text
	_growth_title.visible = true

	for b in _growth_buttons:
		b.queue_free()
	_growth_buttons.clear()

	var card_w := 210.0
	var card_h := 270.0
	var gap := 16.0
	var total_w := offers.size() * card_w + (offers.size() - 1) * gap
	var start_x := (VIEW_W - total_w) * 0.5

	for i in range(offers.size()):
		var offer: Dictionary = offers[i]
		var def: UnitDefinition = offer["unit_def"]
		var kind: String = offer.get("kind")
		var accent := GOLD
		if kind == "levelup":
			accent = LEVEL_UP_ACCENT
		elif kind == "add":
			accent = REINFORCE_ACCENT

		var offer_level: int = int(offer.get("level", 1))
		var offer_count: int = int(offer.get("count", 1))

		var title: String
		var detail: String
		var badge: String
		if kind == "double":
			title = "DUPLICATE"
			detail = "%d → %d units" % [offer_count, offer_count * 2]
			badge = "Lv.%d" % offer_level
		elif kind == "levelup":
			title = "LEVEL UP"
			detail = "%d units → Lv.%d" % [offer_count, offer_level + 1]
			badge = "Lv.%d" % (offer_level + 1)
		else:
			title = "REINFORCE"
			detail = "New unit: %s" % def.display_name
			badge = "Lv.1"

		var pos := Vector2(start_x + i * (card_w + gap), VIEW_H * 0.5 - card_h * 0.5)
		var card := _build_offer_card(pos, Vector2(card_w, card_h), accent, def.sprite, badge, title, detail,
			func(idx: int = i) -> void: growth_offer_picked.emit(idx))
		_growth_buttons.append(card)

	var picked: int = await growth_offer_picked
	_growth_title.visible = false
	for b in _growth_buttons:
		b.queue_free()
	_growth_buttons.clear()
	return picked


# ---------------------------------------------------------------- unit views

const STUN_STAR_COLOR := Color(1.0, 0.9, 0.2)
const STUN_ORBIT_RADIUS := 20.0
const STUN_STAR_COUNT := 3
const STUN_SPIN_RATE := 4.0


func _build_star(color: Color, size: float) -> Polygon2D:
	var star := Polygon2D.new()
	var points := PackedVector2Array()
	var outer := size
	var inner := size * 0.42
	for i in range(10):
		var angle := deg_to_rad(i * 36.0 - 90.0)
		var r := outer if i % 2 == 0 else inner
		points.append(Vector2(cos(angle), sin(angle)) * r)
	star.polygon = points
	star.color = color
	return star


## Warcraft 3-style stun indicator: a few small stars orbiting above the
## unit's head while stagger_timer > 0 -- no new art, just procedural
## Polygon2D shapes (same "no extra assets needed" approach as the impact
## particles). A separate, always-on-top effect from the yellow sprite tint
## so a staggered unit reads as "stunned" even at a glance where the tint
## alone might be missed.
func _build_stun_fx() -> Node2D:
	var container := Node2D.new()
	container.z_index = 6
	container.visible = false
	for i in range(STUN_STAR_COUNT):
		var star := _build_star(STUN_STAR_COLOR, 7.0)
		var angle := deg_to_rad(i * 360.0 / STUN_STAR_COUNT)
		star.position = Vector2(cos(angle), sin(angle)) * STUN_ORBIT_RADIUS
		container.add_child(star)
	add_child(container)
	return container


func _build_unit_view(u: SimUnit) -> Dictionary:
	var team_color := TeamColor.color_for_side(u.team)
	# HP bar/ring shrink with the sprite, but not as aggressively -- they stay
	# legible even when a crowded round shrinks sprites well below REF_SCALE.
	var bar_ratio := clampf(_unit_scale / REF_SCALE, 0.55, 1.0)

	var sprite := Sprite2D.new()
	sprite.texture = u.def.idle_sprite_for_level(u.level)
	var base_scale := Vector2(_unit_scale, _unit_scale)
	sprite.scale = base_scale
	TeamColor.apply(sprite, team_color)
	add_child(sprite)

	# Crossfade overlay for the idle breathing loop (see _update_view()) --
	# holds the UPCOMING frame at partial alpha while `sprite` holds the
	# current one, so the 4-frame loop reads as smooth motion instead of a
	# hard frame-to-frame snap every ~0.45s, which is what read as
	# "robotic/choppy" with a plain texture swap.
	var idle_blend := Sprite2D.new()
	idle_blend.visible = false
	TeamColor.apply(idle_blend, team_color)
	add_child(idle_blend)

	var ring := ColorRect.new()
	ring.color = team_color
	ring.color.a = 0.85
	ring.size = Vector2(70, 14) * bar_ratio
	ring.z_index = -1
	add_child(ring)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.6)
	hp_bg.size = Vector2(90, 10) * bar_ratio
	add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = team_color
	hp_fill.size = hp_bg.size
	add_child(hp_fill)

	var stun_fx := _build_stun_fx()

	return {
		"unit": u,
		"sprite": sprite,
		"idle_blend": idle_blend,
		"ring": ring,
		"hp_bg": hp_bg,
		"hp_fill": hp_fill,
		"stun_fx": stun_fx,
		"base_scale": base_scale,
		"prev_pos": u.pos,
		"walk_phase": 0.0,
		"punch_scale": 1.0,
		"punch_offset": Vector2.ZERO,
		"hit_offset": Vector2.ZERO,
		"death_played": false,
		"attack_anim_playing": false,
		"hp_display_frac": 1.0,
		"hp_frozen": false,
		"walk_frame_display": 0,
	}


func _sim_to_screen(pos: Vector2) -> Vector2:
	var y := lerpf(LANE_BOTTOM_Y, LANE_TOP_Y, pos.x / BattleSim.ARENA_WIDTH)
	var spread := (pos.y - BattleSim.ARENA_DEPTH * 0.5) / BattleSim.ARENA_DEPTH
	var x := VIEW_W * 0.5 + spread * (LANE_WIDTH * 0.98)
	return Vector2(x, y)


func _consume_events() -> void:
	for e in _sim.events:
		if e.type == "attack" or e.type == "heal":
			var v := _view_for(e.attacker_id)
			if not v.is_empty():
				_punch(v)
			var target_v := _view_for(e.target_id)
			if not target_v.is_empty():
				var team_color := TeamColor.color_for_side(v.unit.team) if not v.is_empty() else Color.WHITE
				# Splash attackers (Demolitionist) get a real lobbed projectile
				# instead of an instant impact -- the explosion (impact burst +
				# hit-flash + knockback) is delayed until the grenade actually
				# lands, see _fire_projectile(). BattleSim's splash damage hits
				# EVERY enemy within splash_radius of target.pos, not just the
				# named target_id -- the event only carries the primary
				# target_id, so this was previously the whole reason "some"
				# hits still looked instant: any unit caught in the blast
				# besides the primary target got its HP bar dropped by the sim
				# tick with zero visual feedback of any kind (no freeze, no
				# flash, no explosion), since only target_v was ever touched.
				# Recomputing the same splash-radius membership check here
				# (mirroring BattleSim._attack()'s own logic) and treating
				# every victim identically fixes that for the whole blast, not
				# just whichever unit happened to be the named target.
				if e.type == "attack" and not v.is_empty() and v.unit.def.splash_radius > 0.0:
					var victims: Array[Dictionary] = []
					for other_v in _views:
						var other: SimUnit = other_v.unit
						if not other.alive or other.team == v.unit.team:
							continue
						if other.pos.distance_to(target_v.unit.pos) <= v.unit.def.splash_radius:
							victims.append(other_v)
					_fire_projectile(_sim_to_screen(v.unit.pos), target_v.unit.pos, victims, team_color)
					continue
				_spawn_impact(_sim_to_screen(target_v.unit.pos), team_color)
				# Heals shouldn't flash white / flinch the healed ally -- that
				# reads as damage, not support.
				if e.type == "attack":
					_hit_flash(target_v)
					if not v.is_empty():
						var away := _sim_to_screen(target_v.unit.pos) - _sim_to_screen(v.unit.pos)
						_knockback(target_v, away)


func _view_for(unit_id: int) -> Dictionary:
	for v in _views:
		if v.unit.id == unit_id:
			return v
	return {}


func _update_view(v: Dictionary) -> void:
	var u: SimUnit = v.unit
	var screen_pos := _sim_to_screen(u.pos)
	var sprite: Sprite2D = v.sprite
	var idle_blend: Sprite2D = v.idle_blend

	if not u.alive:
		idle_blend.visible = false
		if not v.death_played:
			v.death_played = true
			_play_death(v)
		return

	var base_scale: Vector2 = v.base_scale

	# Heavy Strikes' stagger has no dedicated art (a level-up ability, not a
	# new unit) -- a flat warm-yellow tint reads as "dazed" cheaply and
	# doesn't fight the white hit-flash pulse (a separate shader uniform,
	# composes fine with a CanvasItem-level modulate on top of it).
	sprite.modulate = Color(1.0, 0.85, 0.3) if u.stagger_timer > 0.0 else Color.WHITE

	# Moving vs idle are visually distinct states, not one wobble applied on
	# top of whatever the sim happens to be doing to .pos -- that's what read
	# as "slithering": a smoothly-translating sprite independently rotating
	# and scaling off an unrelated sine phase looks like it's sliding, not
	# walking. Moving units get a footstep-style bounce (no rotation, so they
	# don't tilt sideways while sliding); stationary units (holding range,
	# on attack cooldown, dead-center at the wall) get the original gentle
	# idle sway instead.
	var prev_pos: Vector2 = v.prev_pos
	var moved := u.pos.distance_to(prev_pos)
	v.prev_pos = u.pos
	var moving := moved > 0.002

	# Retreating vs advancing get different real frame sets (see
	# UnitDefinition.retreat_frames) -- same "which way is this unit actually
	# facing/moving relative to what it cares about" check the 3D project's
	# unit_view.gd used: a support unit flees its threat_id, everyone else
	# backs off from target_id. Comparing this tick's actual movement vector
	# to the direction toward that reference point (rather than trusting a
	# sim-side flag that doesn't exist) is what correctly distinguishes
	# "closing in" from "kiting away" for the same unit within one battle.
	var retreating := false
	if moving:
		var reference_id := u.threat_id if u.def.is_support else u.target_id
		if reference_id >= 0:
			var ref_v := _view_for(reference_id)
			if not ref_v.is_empty():
				var to_ref: Vector2 = ref_v.unit.pos - u.pos
				if to_ref.length_squared() > 0.0001:
					var move_dir: Vector2 = u.pos - prev_pos
					retreating = move_dir.dot(to_ref) < 0.0

	# Bob/squash amplitudes are fractions of base_scale, not absolute constants
	# -- a real bug, not just a tuning choice: they were tuned as flat numbers
	# (0.05, 0.025) back when the sprite's base scale was ~0.3, where that was
	# a modest ~16% wobble. Once base scale dropped to 0.16 (and lower still
	# for grown rosters via _unit_scale_for()), those same flat numbers became
	# a 30%+ distortion -- which is exactly what was showing up as sprites
	# stretching into thin slivers, confirmed by printing the actual per-frame
	# scale values, not assumed from reading the formula. Expressing them as
	# fractions of base_scale keeps the wobble visually consistent at any
	# roster-size-driven scale.
	# Default off; only the true idle-and-not-attacking case below turns this
	# back on. Moving and mid-attack both keep it hidden -- crossfading only
	# matters for the held breathing pose.
	idle_blend.visible = false

	var walk_offset := Vector2.ZERO
	if moving:
		# Pure distance accumulation (world units moved), not pre-multiplied --
		# a real bug was here: multiplying by 10 at accumulation time and then
		# by another 2 at frame-select time (effectively *20) made the frame
		# index jump non-sequentially frame to frame (e.g. 1,3,1,3...) instead
		# of cycling 0,1,2,3 in order, which is what actually read as "tweaky."
		# Dividing raw distance by a fixed per-frame stride guarantees strictly
		# forward, in-order cycling; a slower unit's cycle plays proportionally
		# slower too, which is correct (foot-locked to distance, not time).
		v.walk_phase += moved
		var frames: Array = u.def.retreat_frames_for_level(u.level) if retreating else u.def.walk_frames_for_level(u.level)
		if frames.is_empty():
			frames = u.def.walk_frames_for_level(u.level)
		if not frames.is_empty():
			const WALK_FRAME_DISTANCE := 0.4
			# Real spritesheet frames carry the motion themselves -- no
			# procedural squash/bounce on top, same "don't double-animate"
			# rule as attack_frames vs the procedural punch.
			# Advance the DISPLAYED frame by at most one step per rendered
			# frame, even if the accumulator caught up several sim ticks at
			# once (see the tick cap above) and the raw distance-based target
			# jumped by more than one stride -- otherwise a frame-rate hiccup
			# makes the animation visibly skip frames instead of just briefly
			# lagging behind, which reads as choppy/tweaky regardless of how
			# correct the underlying distance math is.
			var target_idx := int(v.walk_phase / WALK_FRAME_DISTANCE) % frames.size()
			if v.walk_frame_display != target_idx:
				v.walk_frame_display = (v.walk_frame_display + 1) % frames.size()
			sprite.texture = frames[v.walk_frame_display]
			sprite.scale = base_scale
			sprite.rotation = 0.0
			# A hard on/off bounce keyed directly off the current frame index
			# (not a sine wave) -- this is what actually reads as "steppy":
			# an abrupt snap between two heights every time the frame changes,
			# instead of a continuous glide with only the flat art swapping.
			if v.walk_frame_display % 2 == 0:
				walk_offset = Vector2(0.0, -8.0 * (_unit_scale / REF_SCALE))
		else:
			# Kept deliberately subtle -- reference footage (Draft Showdown's
			# own trailer, frame-extracted for comparison) shows units
			# advancing as a tight row with only a small per-unit wobble, not
			# an exaggerated per-step hop/squash.
			var phase: float = v.walk_phase * 10.0
			var step: float = absf(sin(phase))
			var squash := sin(phase * 2.0) * base_scale.x * 0.05
			sprite.scale = base_scale + Vector2(squash, -squash)
			sprite.rotation = 0.0
			walk_offset = Vector2(0.0, -step * 4.0 * (_unit_scale / REF_SCALE))
	elif not v.attack_anim_playing:
		# Real 4-frame breathing loop (see UnitDefinition.idle_frames) --
		# replaces the old sine-wave scale/rotation wobble on a static frame,
		# which wasn't actually an animation and read as fake. Per-unit phase
		# offset (u.id-based) keeps a crowd from breathing in lockstep, same
		# idea the old code used for its sine phase.
		#
		# Crossfading `idle_blend` (the upcoming frame) in over `sprite` (the
		# current one) as the phase advances through each frame's slice is
		# what makes this read as smooth motion instead of a hard snap every
		# ~0.45s -- 4 static poses swapped instantly is exactly what looked
		# "robotic/choppy" before this. Position/scale/rotation are mirrored
		# onto idle_blend further below, once sprite's own final transform for
		# this frame (including the punch multiplier) is known.
		var idle_frames := u.def.idle_frames_for_level(u.level)
		if idle_frames.size() >= 2:
			var n := idle_frames.size()
			var loop_t := fmod(_breathe_phase / BREATHE_PERIOD + float(u.id) * 0.27, 1.0) * n
			var idx := int(loop_t) % n
			var next_idx := (idx + 1) % n
			var frac: float = loop_t - float(int(loop_t))
			sprite.texture = idle_frames[idx]
			idle_blend.texture = idle_frames[next_idx]
			idle_blend.modulate = sprite.modulate
			idle_blend.modulate.a = frac
			idle_blend.visible = true
		else:
			sprite.texture = u.def.idle_sprite_for_level(u.level)
		sprite.scale = base_scale
		sprite.rotation = 0.0

	# Attack punch is a separate multiplier/offset (see _punch()) instead of a
	# tween writing sprite.scale/position directly -- this per-frame block runs
	# every _process() and would otherwise stomp the tween's value one frame
	# after it set it, which is why attacks previously read as having no
	# animation at all.
	var punch_scale: float = v.punch_scale
	var punch_offset: Vector2 = v.punch_offset
	var hit_offset: Vector2 = v.hit_offset
	sprite.scale *= punch_scale
	sprite.position = screen_pos + walk_offset + punch_offset + hit_offset

	# Mirror the idle crossfade overlay onto sprite's just-finalized transform
	# (including the punch multiplier) so it lines up pixel-for-pixel with the
	# base frame underneath -- has to happen here, after position/scale above,
	# not back in the idle branch where those aren't computed yet.
	if idle_blend.visible:
		idle_blend.position = sprite.position
		idle_blend.scale = sprite.scale
		idle_blend.rotation = sprite.rotation

	# Offsets derived from the sprite's actual half-height (texture is 512px,
	# so 256 * scale) rather than fixed pixel values, so the HP bar/ring
	# track the sprite correctly at any scale instead of only whatever
	# resolution they were hand-tuned against. (2026-08-27: briefly
	# downscaled to 320px to fit under a 50MB delivery cap, then explicitly
	# reverted at the user's request -- they'd rather find another delivery
	# path than ship lower-resolution art. Don't re-downscale without asking.)
	var half_h := 256.0 * base_scale.x
	var hp_w: float = v.hp_bg.size.x
	v.ring.position = screen_pos + Vector2(-v.ring.size.x * 0.5, half_h * 0.464)
	v.hp_bg.position = screen_pos + Vector2(-hp_w * 0.5, -half_h * 1.221)
	v.hp_fill.position = v.hp_bg.position
	# BattleSim resolves damage the instant the attack tick runs, but a lobbed
	# grenade's impact is deliberately delayed (see _fire_projectile()) -- so a
	# splash target's HP bar display is frozen at its pre-hit value the moment
	# the grenade launches and only allowed to catch up to the real (already
	# lower) hp_fraction() once the explosion actually lands. Without this the
	# bar visibly drops before the grenade even arrives, reading as "damage on
	# fire" instead of "damage on impact."
	if not v.hp_frozen:
		v.hp_display_frac = u.hp_fraction()
	v.hp_fill.size.x = hp_w * v.hp_display_frac

	var stun_fx: Node2D = v.stun_fx
	stun_fx.visible = u.stagger_timer > 0.0
	if stun_fx.visible:
		stun_fx.position = screen_pos + Vector2(0, -half_h * 1.221 - 34.0)
		stun_fx.rotation = _idle_phase * STUN_SPIN_RATE


## Animates v.punch_scale/v.punch_offset (read by _update_view every frame,
## see the comment there) rather than tweening the sprite's own scale/position
## directly -- those are already being set unconditionally every _process()
## frame for movement/idle, and a tween writing the same properties would just
## get overwritten one frame later, which is why attacks previously had no
## visible animation at all.
##
## Kept small on purpose: Draft Showdown's own reference footage barely moves
## the attacking unit's body at all on a hit -- the impact reads mainly through
## a small particle puff on the TARGET (see _spawn_impact(), called from
## _consume_events() alongside this) rather than a big lunge/squash on the
## attacker. This used to be a much bigger pop (1.22x, 14px lunge); toned down
## to match that reference instead of inventing our own exaggerated version.
func _punch(v: Dictionary) -> void:
	var u: SimUnit = v.unit
	if u.def.attack_frames.size() > 0:
		_play_attack_frames(v)
		return

	var lunge_dist := 5.0 * (_unit_scale / REF_SCALE)
	var lunge := Vector2(0.0, -lunge_dist if u.team == 0 else lunge_dist)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(s: float) -> void: v.punch_scale = s, 1.0, 1.08, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(o: Vector2) -> void: v.punch_offset = o, Vector2.ZERO, lunge, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().set_parallel(true)
	tw.tween_method(func(s: float) -> void: v.punch_scale = s, 1.08, 1.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(o: Vector2) -> void: v.punch_offset = o, lunge, Vector2.ZERO, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Plays a real spritesheet-derived attack animation (idle/windup/strike/
## recover) instead of the procedural scale-punch, for units whose
## UnitDefinition has attack_frames set. Guarded against overlap: if this
## unit's attack speed ever outpaces the sequence length, a re-trigger mid-
## sequence is dropped rather than starting a second sequence that would
## fight the first one over sprite.texture.
func _play_attack_frames(v: Dictionary) -> void:
	if v.attack_anim_playing:
		return
	v.attack_anim_playing = true

	var def: UnitDefinition = v.unit.def
	if def.is_support:
		pass  # healing has no shoot/swing/strike sound yet
	elif def.type == UnitDefinition.UnitType.MELEE:
		_play_sfx(SFX_SWING)
	else:
		_play_sfx(SFX_SHOOT)

	var frames: Array = v.unit.def.attack_frames_for_level(v.unit.level)
	var sprite: Sprite2D = v.sprite
	var base_tex: Texture2D = v.unit.def.idle_sprite_for_level(v.unit.level)
	var frame_time := 0.08

	var tw := create_tween()
	for i in range(frames.size()):
		tw.tween_callback(func(idx: int = i) -> void: sprite.texture = frames[idx])
		tw.tween_interval(frame_time)
	tw.tween_callback(func() -> void:
		sprite.texture = base_tex
		v.attack_anim_playing = false
	)


## A lobbed grenade: a small glowing projectile arcs from the attacker to the
## impact point over ~0.28s (two tweened legs, up then down, for a simple
## parabola without needing a real physics arc), then the actual explosion
## (bigger impact burst + hit-flash) fires once it lands -- fire-and-forget
## from _consume_events(), same unawaited-async pattern already used for round
## transitions elsewhere in this file.
##
## `victims` is every enemy view within splash_radius of impact_pos (computed
## by the caller, mirroring BattleSim's own splash-membership check) -- ALL of
## them get the same frozen-HP-until-landing + hit-flash treatment as the
## primary target, not just whichever unit the sim happened to name as
## target_id. Without this, any unit caught in the blast besides the named
## target had its HP bar drop with zero visual feedback at all, which is what
## made the explosion look like it had "no impact" in a real multi-unit fight
## even after the primary target's own timing was fixed.
func _fire_projectile(from_pos: Vector2, impact_pos: Vector2, victims: Array[Dictionary], team_color: Color) -> void:
	var to_pos := _sim_to_screen(impact_pos)
	var scale_ratio := _unit_scale / REF_SCALE
	for victim in victims:
		victim.hp_frozen = true

	var proj := ColorRect.new()
	var size := 10.0 * scale_ratio
	proj.size = Vector2(size, size)
	proj.color = Color(1.0, 0.65, 0.15)
	proj.position = from_pos - proj.size * 0.5
	proj.z_index = 5
	add_child(proj)

	var arc_height := 70.0 * scale_ratio
	var peak := (from_pos + to_pos) * 0.5 - Vector2(0.0, arc_height)
	var leg_time := 0.14

	var tw := create_tween()
	tw.tween_property(proj, "position", peak - proj.size * 0.5, leg_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(proj, "position", to_pos - proj.size * 0.5, leg_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	proj.queue_free()

	_spawn_explosion(to_pos)
	for victim in victims:
		victim.hp_frozen = false
		_hit_flash(victim)


## Small particle puff at the point of impact -- this, not a big lunge on the
## attacker, is how Draft Showdown's reference footage actually communicates a
## hit landing. A few tiny squares fling outward from the contact point and
## fade over ~0.25s, then free themselves.
func _spawn_impact(pos: Vector2, color: Color, n: int = 4, size_mult: float = 1.0, travel_mult: float = 1.0) -> void:
	for i in range(n):
		var chip := ColorRect.new()
		var size := 6.0 * (_unit_scale / REF_SCALE) * size_mult
		chip.size = Vector2(size, size)
		chip.color = color
		chip.position = pos - chip.size * 0.5
		chip.rotation = randf() * TAU
		chip.z_index = 6
		add_child(chip)

		var dir := Vector2.RIGHT.rotated((TAU / n) * i + randf_range(-0.3, 0.3))
		var travel := 16.0 * (_unit_scale / REF_SCALE) * travel_mult
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position", chip.position + dir * travel, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(chip, "modulate:a", 0.0, 0.28)
		tw.chain().tween_callback(chip.queue_free)


## A real explosion, not just a bigger impact puff: a bright flash "shockwave"
## square (rotated 45deg, scaled up fast from its own center then faded) plus
## a much bigger/more numerous debris burst than a normal hit, in warm
## fire colors regardless of team -- this is what was missing when the
## grenade "landed" with basically no visual reaction. Used exclusively for
## splash attackers (see _fire_projectile()).
func _spawn_explosion(pos: Vector2) -> void:
	var scale_ratio := _unit_scale / REF_SCALE

	var flash := ColorRect.new()
	var flash_size := 30.0 * scale_ratio
	flash.size = Vector2(flash_size, flash_size)
	flash.pivot_offset = flash.size * 0.5
	flash.position = pos - flash.size * 0.5
	flash.rotation = PI * 0.25
	flash.color = Color(1.0, 0.85, 0.5, 0.95)
	flash.z_index = 7
	add_child(flash)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(3.2, 3.2), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(flash.queue_free)

	_spawn_impact(pos, Color(1.0, 0.55, 0.15), 16, 1.6, 2.2)
	_spawn_impact(pos, Color(0.5, 0.5, 0.52), 6, 1.1, 1.4)


## Brief white flash on the hit target via the shader's flash_amount uniform
## (see team_trim_2d.gdshader) -- mixes in AFTER team recoloring, so it reads
## as a clean white pulse instead of fighting the trim tint the way a
## modulate-based flash would.
func _hit_flash(v: Dictionary) -> void:
	_play_sfx(SFX_STRIKE)
	var mat: ShaderMaterial = v.sprite.material
	mat.set_shader_parameter("flash_amount", 1.0)
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void: mat.set_shader_parameter("flash_amount", f), 1.0, 0.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Small flinch away from the attacker on hit, via v.hit_offset (same
## stomp-avoiding pattern as punch_offset/walk_offset -- see _update_view()).
func _knockback(v: Dictionary, away_dir: Vector2) -> void:
	var dist := 4.0 * (_unit_scale / REF_SCALE)
	var target := Vector2.ZERO
	if away_dir.length() > 0.001:
		target = away_dir.normalized() * dist

	var tw := create_tween()
	tw.tween_method(func(o: Vector2) -> void: v.hit_offset = o, Vector2.ZERO, target, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_method(func(o: Vector2) -> void: v.hit_offset = o, target, Vector2.ZERO, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Death dissolve: fade + shrink over 0.3s plus a color-matched particle
## burst, replacing the old flat per-frame alpha decrement (which faded at a
## fixed rate regardless of framerate and never scaled the sprite down at
## all). Runs once, on the alive->dead transition (see _update_view()).
func _play_death(v: Dictionary) -> void:
	var sprite: Sprite2D = v.sprite
	v.ring.visible = false
	v.hp_bg.visible = false
	v.hp_fill.visible = false
	v.stun_fx.visible = false

	var team_color := TeamColor.color_for_side(v.unit.team)
	_spawn_impact(sprite.position, team_color, 6)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tw.tween_property(sprite, "scale", sprite.scale * 0.7, 0.3)
