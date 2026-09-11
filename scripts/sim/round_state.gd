class_name RoundState
extends RefCounted
## Ported from the 3D Cyber Draft-Duel project's round_state.gd, then reworked
## (2026-08-26) from a continuous per-instance power multiplier to a discrete
## per-instance LEVEL, because that's what "doubling" was always supposed to
## mean: duplicating the roster COUNT of one specific (unit type, level)
## group, not scaling one instance's stats. Levels are also promotable in
## place mid-match ("level up" offers, separate from "double" offers) -- see
## roll_offers()/apply_offer() below. BattleSim itself is untouched: it still
## just wants a flat power-multiplier float per slot, so power_a/power_b stay
## as derived arrays (power_for_level(level), rebuilt via _rebuild_power()
## whenever levels change) rather than a stat the sim needs to know about.
##
## Level-up gating (2026-08-26): every unit always STARTS a match at level 1
## -- PlayerProfile's out-of-match progression doesn't grant a head start, it
## only unlocks which "level up" offers are even allowed to appear in a
## match at all (see roll_offers()'s max_level_by_path param). RoundState
## itself stays decoupled from PlayerProfile (an autoload) for the same
## testability reason BattleSim is decoupled -- the caller (match_controller.
## gd) resolves the unlock dict and passes it in as plain data.

const LIVES_PER_SIDE := 3
const BASE_GROWTH := 2
const COMEBACK_BONUS := 1
const MAX_ROUNDS := 10

## A DRAW replays the SAME round_number with a fresh seed and does not
## advance it (see record_round_result()) -- is_match_over()'s round_number
## check therefore can't ever end a match that keeps drawing. That's a real
## infinite-loop risk, not a hypothetical one: a genuinely symmetric
## standoff (e.g. two matched LONG-row shootouts with SUPPORT healing both
## sides at a similar rate to incoming damage -- reported 2026-09-07 after
## the rank/formation system made ranged-vs-ranged standoffs common) can
## draw on seed after seed. match_controller.gd's _on_round_finished()
## checks draw_retry against this and force-resolves via the last sim's own
## HP-total tiebreak (the same logic BattleSim already uses for its own
## MATCH_TIMEOUT) rather than replaying past it.
const MAX_DRAW_RETRIES := 4

## Stat multiplier per level, level 1 = baseline (1.0x). Shared by both the
## in-match "level up" offer and the out-of-match menu progression
## (PlayerProfile) -- a level means the same thing wherever it came from.
const LEVEL_POWER_STEP := 0.5
## Only 3 levels total (Lv.1 base + 2 unlockable tiers) -- deliberately small
## so each level-up can be a substantial, curated jump rather than a long
## grindy ladder. See PlayerProfile for the unlock-tier side of this.
const MAX_LEVEL := 3

## auto_grow_side() (bot / online-automatic path) only ever duplicates or adds
## -- it never levels up. The bot has no PlayerProfile/Heroes-menu unlocks,
## and "level up" offers are gated on those (see roll_offers()), so giving
## the bot free level-ups would be a different, ungated rule than the
## player's. The remaining probability after DOUBLE_CHANCE goes to "add".
const DOUBLE_CHANCE := 0.2

## Measured 2026-09-06 via tools/bot_vs_progressed_harness.gd: a
## fully-progressed human (every tier unlocked, always picks the
## mathematically strongest offer) wins ~70% of matches against the
## unmodified bot above, which only manages ~10%. The gap is real and large,
## not tuning noise -- doubling is a flat 2x on a group's total power/HP
## every time (see power_for_level()'s doc comment), strictly stronger than
## one level-up step, and the bot has zero access to leveling to compensate.
## Rather than just cranking the baseline constants (which would also make
## the bot too hard for a fresh player with nothing unlocked, since it's the
## same bot for everyone), auto_grow_side() takes a `difficulty_scale`
## (0.0-1.0, driven by the human's actual Heroes-menu investment -- see
## match_controller.gd's _bot_difficulty_scale()) and leans harder into
## doubling as that rises: 0.0 reproduces today's exact baseline (a fresh
## player faces the bot unchanged), 1.0 pushes the bot to compensate for its
## structural leveling disadvantage the only way it can.
## First calibration attempt used 2.0/0.6 and overshot violently -- 80% bot
## wins / 0% human wins at difficulty_scale=1.0 (measured 2026-09-06), because
## doubling compounds multiplicatively round over round, not linearly. These
## much smaller values are the second calibration point; see the same
## harness for the actual measured result before trusting this further.
const BOT_MAX_GROWTH_MULT := 1.25
const BOT_MAX_DOUBLE_CHANCE := 0.32

var lives_a: int = LIVES_PER_SIDE
var lives_b: int = LIVES_PER_SIDE
var round_number: int = 1

var roster_a: Array[UnitDefinition] = []
var roster_b: Array[UnitDefinition] = []
## Parallel to roster_a/roster_b -- the source of truth for each instance's
## level. power_a/power_b (below) are derived from these, not the other way
## around.
var levels_a: Array[int] = []
var levels_b: Array[int] = []
## Derived per-slot stat multipliers, kept in sync with levels_a/levels_b by
## _rebuild_power() -- this is the array BattleSim.setup() actually reads.
var power_a: Array[float] = []
var power_b: Array[float] = []
## The distinct types drafted at match start -- roster growth only ever draws
## from this, per side, for the whole match.
var type_pool_a: Array[UnitDefinition] = []
var type_pool_b: Array[UnitDefinition] = []

var last_round_result: int = BattleSim.Result.IN_PROGRESS
var match_seed: int = 0
## Bumped on a DRAW so the replay of the same round_number uses a fresh seed
## instead of reproducing the identical draw forever; reset once a real result lands.
var draw_retry: int = 0


## p_levels_a/p_levels_b let a caller seed starting levels (from
## PlayerProfile, for the human's drafted hand) -- default/mismatched-size
## arrays fall back to all level 1, which is also what bot hands always use
## (no meta-progression for the bot).
func init(hand_a: Array[UnitDefinition], hand_b: Array[UnitDefinition], p_match_seed: int,
		p_levels_a: Array[int] = [], p_levels_b: Array[int] = []) -> void:
	init_with_deployment(hand_a, hand_a, hand_b, p_match_seed, p_levels_a, p_levels_b)


## Like init(), but the human's deployed round-1 squad can differ from the
## types drafted -- match_controller.gd's _resolve_initial_deployment()
## (2026-09-11) lets the player field any multiset of their 4 drafted types
## (e.g. 2 Enforcers + 2 Troopers, or 4 of one type) via the same "choose 1
## of 3" upgrade cards mid-match growth picks use, instead of always exactly
## one of each. type_pool_a (what "add" growth offers can bring in for the
## rest of the match) still comes from drafted_types_a, not deployed_a -- a
## type left undeployed at round 1 can still show up later. The bot side has
## no deploy picker, so its drafted types and deployed squad are always the
## same array (init() above just forwards hand_a as both).
func init_with_deployment(deployed_a: Array[UnitDefinition], drafted_types_a: Array[UnitDefinition], hand_b: Array[UnitDefinition], p_match_seed: int,
		p_levels_a: Array[int] = [], p_levels_b: Array[int] = []) -> void:
	match_seed = p_match_seed
	lives_a = LIVES_PER_SIDE
	lives_b = LIVES_PER_SIDE
	round_number = 1
	last_round_result = BattleSim.Result.IN_PROGRESS

	roster_a = deployed_a.duplicate()
	roster_b = hand_b.duplicate()
	levels_a = p_levels_a.duplicate() if p_levels_a.size() == deployed_a.size() else _ones(deployed_a.size())
	levels_b = p_levels_b.duplicate() if p_levels_b.size() == hand_b.size() else _ones(hand_b.size())
	_rebuild_power(0)
	_rebuild_power(1)
	type_pool_a = _distinct_types(drafted_types_a)
	type_pool_b = _distinct_types(hand_b)


static func power_for_level(level: int) -> float:
	return 1.0 + float(maxi(level, 1) - 1) * LEVEL_POWER_STEP


func _ones(count: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(count):
		out.append(1)
	return out


func _rebuild_power(side: int) -> void:
	var levels := levels_a if side == 0 else levels_b
	var power: Array[float] = []
	for lvl in levels:
		power.append(power_for_level(lvl))
	if side == 0:
		power_a = power
	else:
		power_b = power


func _distinct_types(hand: Array[UnitDefinition]) -> Array[UnitDefinition]:
	var pool: Array[UnitDefinition] = []
	for u in hand:
		if not pool.has(u):
			pool.append(u)
	return pool


## Every roster index whose (def, level) matches -- used by both offer
## application and auto-grow so "double"/"level up" always act on the WHOLE
## group, never just the one instance a random pick happened to land on.
func _indices_matching(roster: Array[UnitDefinition], levels: Array[int], def: UnitDefinition, level: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(roster.size()):
		if roster[i] == def and levels[i] == level:
			out.append(i)
	return out


func current_seed() -> int:
	return match_seed + round_number * 1000 + draw_retry


func record_round_result(result: int) -> void:
	last_round_result = result
	if result == BattleSim.Result.DRAW:
		draw_retry += 1
		return
	draw_retry = 0
	if result == BattleSim.Result.TEAM_A:
		lives_b -= 1
	elif result == BattleSim.Result.TEAM_B:
		lives_a -= 1


func is_match_over() -> bool:
	return lives_a <= 0 or lives_b <= 0 or round_number > MAX_ROUNDS


## -1 = draw (only reachable via the round cap safety net).
func winner_team() -> int:
	if lives_a <= 0 and lives_b <= 0:
		return -1
	if lives_a <= 0:
		return 1
	if lives_b <= 0:
		return 0
	if lives_a > lives_b:
		return 0
	elif lives_b > lives_a:
		return 1
	return -1


func grow_for_next_round() -> void:
	var a_lost := last_round_result == BattleSim.Result.TEAM_B
	var b_lost := last_round_result == BattleSim.Result.TEAM_A
	auto_grow_side(0, a_lost)
	auto_grow_side(1, b_lost)
	round_number += 1


func auto_grow_side(side: int, comeback: bool, difficulty_scale: float = 0.0) -> void:
	var roster := roster_a if side == 0 else roster_b
	var levels := levels_a if side == 0 else levels_b
	var type_pool := type_pool_a if side == 0 else type_pool_b
	if type_pool.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed() * 2 + side
	var scale := clampf(difficulty_scale, 0.0, 1.0)
	var growth_mult := lerpf(1.0, BOT_MAX_GROWTH_MULT, scale)
	var double_chance := lerpf(DOUBLE_CHANCE, BOT_MAX_DOUBLE_CHANCE, scale)
	var count := int(round(additions_for(comeback) * growth_mult))
	for i in range(count):
		var roll := rng.randf()
		if roster.size() > 0 and roll < double_chance:
			var idx := rng.randi_range(0, roster.size() - 1)
			var group := _indices_matching(roster, levels, roster[idx], levels[idx])
			for _g in group:
				roster.append(roster[idx])
				levels.append(levels[idx])
		else:
			var type_idx := rng.randi_range(0, type_pool.size() - 1)
			roster.append(type_pool[type_idx])
			levels.append(1)
	_rebuild_power(side)


func additions_for(comeback: bool) -> int:
	return BASE_GROWTH + (COMEBACK_BONUS if comeback else 0)


## Rolls 2-3 candidate offers for ONE growth slot for the given side. Three
## kinds: "double" (duplicate a (type, level) group's count), "levelup"
## (promote every instance in a (type, level) group to level+1, in place),
## "add" (bring in a fresh level-1 instance of an undrafted type from the
## pool). One "double"/"levelup" pair is offered per DISTINCT group present,
## not per roster index -- with [Enforcer L1, Enforcer L2] on the roster,
## that's a separate "×2 Enforcer Lv.1" and "×2 Enforcer Lv.2", exactly so a
## pick can target one level's stack without touching the other.
##
## max_level_by_path (resource_path -> highest level allowed, default 1 for
## anything absent) gates "levelup": a group only offers one if promoting it
## would stay within what's unlocked. Pass {} (the default) to disable
## level-up offers entirely -- exactly what auto_grow_side()/the bot want,
## since level-up is a Heroes-menu-gated player-only mechanic.
## Every distinct group unconditionally got a "double" candidate here before
## 2026-09-11 -- with the shuffle-and-slice below giving each candidate equal
## odds of landing in the revealed 3, that made "double" appear (and get
## picked) very often, and doubling a group's count is a flat 2x on its
## total power (see power_for_level()'s doc comment) -- strictly the
## strongest thing on offer, no real choice most rounds. Rolling it out
## PLAYER_DOUBLE_INCLUDE_CHANCE of the time thins the pool it competes in
## instead of nerfing what it does when it does appear, which felt like the
## actual complaint ("too OP" as in "always the right pick," not "too
## strong once picked").
const PLAYER_DOUBLE_INCLUDE_CHANCE := 0.55


func roll_offers(side: int, slot_index: int, max_level_by_path: Dictionary = {}) -> Array:
	var roster := roster_a if side == 0 else roster_b
	var levels := levels_a if side == 0 else levels_b
	var type_pool := type_pool_a if side == 0 else type_pool_b

	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed() * 2 + side + slot_index * 97

	var groups := {}
	var group_order: Array = []
	for i in range(roster.size()):
		var key := "%s|%d" % [roster[i].resource_path, levels[i]]
		if not groups.has(key):
			groups[key] = {"unit_def": roster[i], "level": levels[i], "count": 0}
			group_order.append(key)
		groups[key]["count"] += 1

	var candidates: Array = []
	for key in group_order:
		var g: Dictionary = groups[key]
		if rng.randf() < PLAYER_DOUBLE_INCLUDE_CHANCE:
			candidates.append({
				"kind": "double", "unit_def": g["unit_def"], "level": g["level"], "count": g["count"],
			})
		var level_cap: int = int(max_level_by_path.get(g["unit_def"].resource_path, 1))
		if g["level"] < mini(level_cap, MAX_LEVEL):
			candidates.append({
				"kind": "levelup", "unit_def": g["unit_def"], "level": g["level"], "count": g["count"],
			})
	for t in type_pool:
		candidates.append({"kind": "add", "unit_def": t})
	if candidates.is_empty():
		return []

	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var count: int = mini(3, candidates.size())
	return candidates.slice(0, count)


func apply_offer(side: int, offer: Dictionary) -> void:
	var roster := roster_a if side == 0 else roster_b
	var levels := levels_a if side == 0 else levels_b
	var kind: String = offer.get("kind")
	if kind == "double":
		var def: UnitDefinition = offer["unit_def"]
		var level: int = int(offer["level"])
		var group_size := _indices_matching(roster, levels, def, level).size()
		for i in range(group_size):
			roster.append(def)
			levels.append(level)
	elif kind == "levelup":
		var def: UnitDefinition = offer["unit_def"]
		var level: int = int(offer["level"])
		for i in _indices_matching(roster, levels, def, level):
			levels[i] += 1
	else:
		roster.append(offer["unit_def"])
		levels.append(1)
	_rebuild_power(side)


func advance_round_number() -> void:
	round_number += 1
