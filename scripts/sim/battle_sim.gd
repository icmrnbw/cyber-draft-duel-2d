class_name BattleSim
extends RefCounted
## Ported verbatim from the 3D Cyber Draft-Duel project (D:\vapecoder\cyber-draft-duel)
## -- this class was always presentation-agnostic, so the combat/movement math is
## reused as-is. `pos.x`/`pos.y` here are an abstract arena plane; the 2D game maps
## them onto the vertical lane's screen X/Y in the view layer, not in here.
##
## Deterministic, headless battle simulation. No Node, no rendering, no Godot physics.
##
## Determinism notes (Stage 7 will audit this — keep it true):
##   - Advances by a fixed TICK_DELTA, never by a frame delta.
##   - All iteration is by index/id, never over an unordered set.
##   - Nearest-enemy ties break by lowest id.
##   - The only randomness is `rng`, always explicitly seeded via setup().
##   - Movement is plain vector math. Godot's physics engine is NOT used anywhere.
##   - REMAINING RISK: Vector2.length()/distance_to() use sqrt, and _retreat_position()
##     uses rotated() (sin/cos). Those can differ in the last bit across architectures.
##     Fine on a single device; revisit in Stage 7 if an Android/iOS cross-check ever
##     desyncs (fixed-point math, or a per-tick lockstep checksum to detect drift).

const TICK_DELTA := 1.0 / 60.0

## Arena, per the design doc: 24m x 14m, hard walls, no cover.
const ARENA_WIDTH := 24.0
const ARENA_DEPTH := 14.0
const UNIT_RADIUS := 0.5

const SPAWN_X_A := 3.0
const SPAWN_X_B := 21.0
## Spawn line spans most of the arena depth so 4 units read as a battle line rather
## than a clump. Team separation along X is unchanged, so balance is barely affected.
const SPAWN_Z_MIN := 3.0
const SPAWN_Z_MAX := 11.0

## Rank/formation system (2026-09-06): every unit already carries a
## UnitDefinition.type (MELEE/MID/LONG/SUPPORT), but spawning ignored it --
## every unit landed on the exact same depth row and got squeezed sideways
## into one shared lateral band. That's what turned a large duplicated stack
## (e.g. 16x Demolitionist from a few "double" picks) into an illegible
## overlapping blob: all 16 sharing space that used to fit 4 different
## types. Each type now gets its OWN depth row (offset from the team's
## spawn line, toward its own side of the arena so team 1's rows mirror
## team 0's) and the FULL lateral band to itself, rather than sharing either
## axis with unrelated types. Tanks (MELEE) sit frontmost -- closest to the
## enemy, soaking the first hits, same tactical role a rank system gives
## them in Draft Showdown -- support (medics) sit backmost, furthest from
## harm. This is a real combat-affecting change (front-loaded melee engages
## sooner, backmost support has more room to kite), not just a visual fix,
## so balance needs re-verifying via tools/balance_harness.gd afterward, not
## assumed unchanged.
## SUPPORT sits ahead of LONG (2026-09-07 adjustment, was the backmost row) --
## a medic that starts further back than the row it's protecting has a
## longer gap to close before it can actually reach an injured Enforcer/
## Trooper up front, which is the opposite of what a healer should want.
const TYPE_ROW_OFFSET := {
	UnitDefinition.UnitType.MELEE: 3.0,
	UnitDefinition.UnitType.MID: 1.5,
	UnitDefinition.UnitType.SUPPORT: 0.75,
	UnitDefinition.UnitType.LONG: 0.0,
}

## Safety net from the design doc — real matches should end well under 30s.
const MATCH_TIMEOUT := 90.0

## Support units flee rather than fight (see _move_support()) -- when the
## last units standing on both sides are support (or otherwise both idle
## with nothing to heal and nobody willing to close the final gap),
## genuinely nothing can happen for the rest of the match: no injured ally
## to heal, no aggressor forcing a retreat, nothing left to change the
## state. Reported directly: two medics as the last unit each side ran the
## match to the full 90s MATCH_TIMEOUT before this existed, which reads as
## "broken," not just "slow." Tracks the last tick ANY action landed (attack,
## heal, or stagger -- not just a kill) rather than time-since-last-DEATH,
## deliberately: a slow tanky 1v1 late in a round can easily go 12s between
## kills while still trading real damage every second, and that's a
## legitimate grind, not a stalemate -- only "genuinely nothing is
## happening" should trigger this, which "no landed action at all" captures
## precisely and "no kill" does not.
const STALEMATE_TIMEOUT := 12.0

enum Result { IN_PROGRESS, TEAM_A, TEAM_B, DRAW }

var units: Array[SimUnit] = []
var elapsed: float = 0.0
var _last_action_elapsed: float = 0.0
var result: Result = Result.IN_PROGRESS
var rng := RandomNumberGenerator.new()

## Per-tick events for the view layer to drain (Stage 4 VFX / Stage 5 SFX hooks).
## Cleared at the start of every tick. [{type="attack", attacker_id, target_id},
## {type="heal", attacker_id, target_id}, {type="death", unit_id}]
var events: Array = []

## Active Firestorm ground patches (UnitDefinition.firepatch_*, see
## _maybe_spawn_fire_patch()/_tick_fire_patches()) -- sim-level state, not
## per-unit, since a patch outlives the attack that created it and has no
## owning unit once placed. Each entry: {pos, remaining, team, dps, radius}.
## `team` is the patch OWNER's team; it damages the opposing team only, same
## rule splash_radius itself already follows.
var _fire_patches: Array = []

## Deferred effects keep attack decisions independent of team iteration order.
## Protective heals resolve before incoming hostile statuses in the same tick.
var _pending_statuses: Array = []
var _pending_protection: Array = []
## Lunge vectors are decided from the same positions as all attacks. Applying
## them only after regular movement prevents lower-id units changing another
## unit's attack range or movement decision within the current tick.
var _pending_lunges: Array = []


## power_a/power_b are optional per-slot multipliers parallel to hand_a/hand_b (for
## the Rounds system's "doubled" units — see rounds-system-design.md). Omitted or
## short arrays default the remaining slots to 1.0, so every existing single-battle
## caller (draft flow, bot, balance harness, smoke tests) is unaffected.
## levels_a/levels_b are the matching discrete levels (see SimUnit.level) --
## same omitted-defaults-to-1 fallback, so this is likewise backward compatible
## with every caller that predates ability levels.
func setup(hand_a: Array[UnitDefinition], hand_b: Array[UnitDefinition], seed_value: int,
		power_a: Array[float] = [], power_b: Array[float] = [],
		levels_a: Array[int] = [], levels_b: Array[int] = []) -> void:
	units.clear()
	events.clear()
	_fire_patches.clear()
	_pending_statuses.clear()
	_pending_protection.clear()
	_pending_lunges.clear()
	elapsed = 0.0
	_last_action_elapsed = 0.0
	result = Result.IN_PROGRESS
	rng.seed = seed_value

	_spawn_hand(hand_a, 0, SPAWN_X_A, power_a, levels_a)
	_spawn_hand(hand_b, 1, SPAWN_X_B, power_b, levels_b)


func _spawn_hand(hand: Array[UnitDefinition], team: int, spawn_x: float, power: Array[float], levels: Array[int]) -> void:
	# Group by type first so each type forms its own row (see
	# TYPE_ROW_OFFSET) with the full lateral band to itself, instead of every
	# unit in the hand sharing one row and one band regardless of type.
	var by_type: Dictionary = {}
	var type_order: Array = []
	for i in range(hand.size()):
		var t: int = hand[i].type
		if not by_type.has(t):
			by_type[t] = []
			type_order.append(t)
		by_type[t].append(i)

	for t in type_order:
		var indices: Array = by_type[t]
		var row_offset: float = TYPE_ROW_OFFSET.get(t, 0.0)
		# Team 0 advances toward +X, team 1 toward -X -- the row offset must
		# point toward each team's OWN side of the spawn line (frontmost =
		# closest to the enemy), so it's negated for team 1, same mirroring
		# rule _retreat_position() already uses for the same reason.
		var row_x := spawn_x + (row_offset if team == 0 else -row_offset)
		var depth_sign := 1.0 if team == 0 else -1.0
		for row_i in range(indices.size()):
			var i: int = indices[row_i]
			var u := SimUnit.new()
			u.id = units.size()
			u.team = team
			u.def = hand[i]
			u.power_multiplier = power[i] if i < power.size() else 1.0
			u.level = levels[i] if i < levels.size() else 1
			u.hp = u.def.hp * u.power_multiplier
			u.pos = _grid_pos(row_i, indices.size(), row_x, depth_sign)
			units.append(u)


## One type's row can massively overflow (2026-09-07: a few "double" picks on
## the same type routinely produce 15-20+ duplicates) -- squeezing that many
## onto ONE lateral line, sharing the same SPAWN_Z_MIN..MAX band the row
## always had, is what turned a big stack into an illegible overlapping mess
## (reported with screenshots; Draft Showdown's own reference shows the fix:
## a tidy multi-row BLOCK, not one overstuffed line). Past
## UNITS_PER_GRID_ROW, wrap into additional depth-offset sub-rows instead,
## centered on the type's nominal row_x so the block grows symmetrically
## fore/aft rather than always bulging toward or away from the enemy.
const UNITS_PER_GRID_ROW := 6
## Tighter than the gap between adjacent type rows (0.75-1.5, see
## TYPE_ROW_OFFSET) so a couple of overflow sub-rows stay contained within a
## type's own territory; a genuinely huge stack (20+) can still nudge into a
## neighboring row's space, which is an acceptable trade against the
## alternative (everything on one line, fully overlapping).
const GRID_ROW_SPACING := 0.65

func _grid_pos(index: int, count: int, row_x: float, depth_sign: float) -> Vector2:
	var grid_row := index / UNITS_PER_GRID_ROW
	var col := index % UNITS_PER_GRID_ROW
	var row_count := mini(UNITS_PER_GRID_ROW, count - grid_row * UNITS_PER_GRID_ROW)
	var total_grid_rows := ceili(float(count) / float(UNITS_PER_GRID_ROW))
	# Centered offset: row 0 of a 3-row block sits at -1, row 1 at 0, row 2
	# at +1 (times GRID_ROW_SPACING) -- symmetric around the nominal row_x
	# regardless of how many sub-rows are needed.
	var centered_row := float(grid_row) - float(total_grid_rows - 1) * 0.5
	var x := row_x + centered_row * GRID_ROW_SPACING * depth_sign
	return Vector2(x, _spawn_z(col, row_count))


func _spawn_z(index: int, count: int) -> float:
	if count <= 1:
		return (SPAWN_Z_MIN + SPAWN_Z_MAX) * 0.5
	var t := float(index) / float(count - 1)
	return lerpf(SPAWN_Z_MIN, SPAWN_Z_MAX, t)


## Advances the simulation exactly TICK_DELTA seconds.
func tick() -> void:
	if result != Result.IN_PROGRESS:
		return

	events.clear()
	elapsed += TICK_DELTA

	_tick_status_effects()
	_acquire_targets()
	_attack()      # decided before movement, so a unit dying this tick still fires
	_tick_fire_patches()
	_apply_pending_protection()
	_apply_pending_statuses()
	_move()
	_apply_pending_lunges()
	_resolve_separation()
	_clamp_to_arena()
	_apply_damage()
	if not events.is_empty():
		_last_action_elapsed = elapsed
	_evaluate_result()


## Runs until the match resolves. Used by the Stage 6 headless harness.
## Returns the number of ticks taken.
func run_to_completion() -> int:
	var ticks := 0
	var max_ticks := int(MATCH_TIMEOUT / TICK_DELTA) + 2
	while result == Result.IN_PROGRESS and ticks < max_ticks:
		tick()
		ticks += 1
	return ticks


func _acquire_targets() -> void:
	for u in units:
		if not u.alive:
			continue
		if u.def.is_support:
			u.target_id = _nearest_injured_ally(u)
			u.threat_id = _nearest_enemy(u)
		else:
			u.target_id = _nearest_enemy(u)


## Ties break by lowest id — required for determinism, and ascending iteration
## order already guarantees that without extra logic (see the Stage 6 write-up on
## why that matters more than it looks like it should).
func _nearest_enemy(u: SimUnit) -> int:
	var best_id := -1
	var best_dist_sq := INF
	for other in units:
		if not other.alive or other.team == u.team:
			continue
		var d := u.pos.distance_squared_to(other.pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best_id = other.id
	return best_id


## An ally counts only if it's actually hurt — a support unit ignores full-health
## allies entirely rather than "healing" them for no effect. Also skips other
## support units entirely (2026-09-07): two medics healing each other instead
## of the DPS/tank units that are actually dying was dragging fights out --
## every heal spent on a fellow healer is a heal a frontline unit didn't get,
## which is what was turning ranged-vs-ranged standoffs into draws.
func _nearest_injured_ally(u: SimUnit) -> int:
	var best_id := -1
	var best_dist_sq := INF
	for other in units:
		if other.id == u.id or not other.alive or other.team != u.team:
			continue
		if other.def.is_support:
			continue
		if other.hp >= other.max_hp():
			continue
		var d := u.pos.distance_squared_to(other.pos)
		if d < best_dist_sq:
			best_dist_sq = d
			best_id = other.id
	return best_id


func _attack() -> void:
	for u in units:
		if not u.alive or u.stagger_timer > 0.0:
			continue
		u.attack_cooldown = maxf(0.0, u.attack_cooldown - TICK_DELTA)
		if u.attack_cooldown > 0.0:
			continue
		if u.def.is_support and _try_self_defense(u):
			continue
		if u.target_id < 0:
			continue
		var target := units[u.target_id]
		if not target.alive or u.pos.distance_to(target.pos) > u.def.preferred_range:
			continue

		u.attack_cooldown = _effective_attack_interval(u)
		var power := u.def.damage_per_hit * u.power_multiplier
		if u.def.is_support:
			target.pending_heal += power
			_queue_heal_protection(u, target)
			events.append({"type": "heal", "attacker_id": u.id, "target_id": target.id, "amount": power})
			continue

		u.attacks_fired += 1
		var special := _is_special_attack(u)
		var hits := maxi(1, u.def.special_attack_hits) if special else 1
		var damage_mult := maxf(0.0, u.def.special_attack_damage_mult) if special else 1.0
		var effect := u.def.special_attack_effect if special else ""
		var dealt := 0.0
		if u.def.splash_radius > 0.0:
			for other in units:
				if other.alive and other.team != u.team and other.pos.distance_to(target.pos) <= u.def.splash_radius:
					for _hit in range(hits):
						dealt += _queue_attack_hit(u, other, power * damage_mult, special)
					if special:
						_queue_special_statuses(u, other)
					_queue_hit_status(u, other, special)
			_maybe_spawn_fire_patch(u, target.pos)
		else:
			for _hit in range(hits):
				dealt += _queue_attack_hit(u, target, power * damage_mult, special)
			if special:
				_queue_special_statuses(u, target)
			_queue_hit_status(u, target, special)
			if special and u.def.special_chain_targets > 0 and u.def.special_chain_damage_mult > 0.0:
				var chain_targets := _find_chain_targets(u, target, u.def.special_chain_targets)
				for chained in chain_targets:
					dealt += _queue_attack_hit(u, chained,
						power * damage_mult * u.def.special_chain_damage_mult, true)
					_queue_special_statuses(u, chained)
					_queue_hit_status(u, chained, true)
				if not chain_targets.is_empty():
					var chain_ids: Array[int] = []
					for chained in chain_targets:
						chain_ids.append(chained.id)
					events.append({"type": "chain", "attacker_id": u.id,
						"target_id": target.id, "targets": chain_ids,
						"amount": dealt})
		if special:
			_queue_lunge(u, target)
			_queue_self_shield(u)
		events.append({"type": "attack", "attacker_id": u.id, "target_id": target.id,
			"effect": effect, "hits": hits, "damage_multiplier": damage_mult})
		if special:
			events.append({"type": "ability", "effect": effect, "attacker_id": u.id,
				"target_id": target.id, "hits": hits, "amount": dealt})


func _is_special_attack(u: SimUnit) -> bool:
	return u.def.special_attack_min_level > 0 and u.level >= u.def.special_attack_min_level \
		and u.def.special_attack_every > 0 and u.attacks_fired % u.def.special_attack_every == 0


func _outgoing_damage_multiplier(u: SimUnit) -> float:
	return 1.0 - clampf(u.suppression_fraction, 0.0, 1.0) if u.suppression_timer > 0.0 else 1.0


func _queue_damage(target: SimUnit, amount: float) -> float:
	var multiplier := 1.0 + maxf(0.0, target.vulnerability_fraction) if target.vulnerability_timer > 0.0 else 1.0
	var damage := maxf(0.0, amount) * multiplier
	target.pending_damage += damage
	if damage > 0.0:
		_last_action_elapsed = elapsed
	return damage


func _queue_attack_hit(u: SimUnit, target: SimUnit, amount: float, special: bool = false) -> float:
	var damage := _queue_damage(target, amount * _outgoing_damage_multiplier(u))
	if special:
		# Partition after suppression and any already-active mark, exactly once.
		# Do not inspect current shields: same-tick protection resolves later.
		target.pending_shield_bypass += damage * clampf(u.def.special_shield_bypass_fraction, 0.0, 1.0)
	if damage > 0.0:
		_maybe_stagger(u, target)
	return damage


func _queue_special_statuses(u: SimUnit, target: SimUnit) -> void:
	if u.def.suppression_min_level > 0 and u.level >= u.def.suppression_min_level:
		_queue_status("suppression", u.id, target.id, u.def.suppression_fraction, u.def.suppression_duration)
	if u.def.mark_min_level > 0 and u.level >= u.def.mark_min_level:
		_queue_status("mark", u.id, target.id, u.def.mark_damage_bonus, u.def.mark_duration)
	if u.def.special_slow_min_level > 0 and u.level >= u.def.special_slow_min_level:
		_queue_status("slow", u.id, target.id, u.def.special_slow_fraction, u.def.special_slow_duration)


func _queue_hit_status(u: SimUnit, target: SimUnit, special: bool) -> void:
	if u.def.on_hit_slow_min_level <= 0 or u.level < u.def.on_hit_slow_min_level:
		return
	if u.def.on_hit_slow_special_only and not special:
		return
	_queue_status("slow", u.id, target.id, u.def.on_hit_slow_fraction, u.def.on_hit_slow_duration)


func _find_chain_targets(u: SimUnit, primary: SimUnit, max_targets: int) -> Array[SimUnit]:
	var candidates: Array[SimUnit] = []
	if u.def.special_chain_radius <= 0.0:
		return candidates
	var radius_squared := u.def.special_chain_radius * u.def.special_chain_radius
	for other in units:
		if other.alive and other.team != u.team and other.id != primary.id \
				and primary.pos.distance_squared_to(other.pos) <= radius_squared:
			candidates.append(other)
	candidates.sort_custom(func(a: SimUnit, b: SimUnit) -> bool:
			var da := primary.pos.distance_squared_to(a.pos)
			var db := primary.pos.distance_squared_to(b.pos)
			return da < db if da != db else a.id < b.id)
	var selected: Array[SimUnit] = []
	for i in range(mini(max_targets, candidates.size())):
		selected.append(candidates[i])
	return selected


func _queue_lunge(u: SimUnit, target: SimUnit) -> void:
	if u.def.special_lunge_distance <= 0.0:
		return
	var offset := target.pos - u.pos
	var distance := offset.length()
	# Stop at contact instead of overshooting the target or swapping sides.
	var travel := minf(u.def.special_lunge_distance, maxf(0.0, distance - UNIT_RADIUS * 2.0))
	if travel > 0.0:
		_pending_lunges.append({"unit_id": u.id, "delta": offset / distance * travel})


func _apply_pending_lunges() -> void:
	for lunge in _pending_lunges:
		units[int(lunge["unit_id"])].pos += Vector2(lunge["delta"])
	_pending_lunges.clear()


func _queue_self_shield(u: SimUnit) -> void:
	if u.def.self_shield_min_level <= 0 or u.level < u.def.self_shield_min_level:
		return
	if u.def.self_shield_amount <= 0.0 or u.def.self_shield_duration <= 0.0:
		return
	var duration := u.def.self_shield_duration
	if u.def.self_shield_duration_upgrade_min_level > 0 and u.level >= u.def.self_shield_duration_upgrade_min_level:
		duration = maxf(duration, u.def.self_shield_upgraded_duration)
	_pending_protection.append({"attacker_id": u.id, "target_id": u.id,
		"amount": u.def.self_shield_amount * u.power_multiplier,
		"cap": u.max_hp() * clampf(u.def.self_shield_cap_fraction, 0.0, 1.0),
		"duration": duration, "cleanse": false, "immunity": 0.0})


func _queue_heal_protection(u: SimUnit, target: SimUnit) -> void:
	if u.def.heal_shield_min_level <= 0 or u.level < u.def.heal_shield_min_level:
		return
	if u.def.heal_shield_amount <= 0.0 or u.def.heal_shield_duration <= 0.0:
		return
	var cleanse := u.def.shield_cleanse_min_level > 0 and u.level >= u.def.shield_cleanse_min_level
	_pending_protection.append({"attacker_id": u.id, "target_id": target.id,
		"amount": u.def.heal_shield_amount * u.power_multiplier,
		"cap": target.max_hp() * clampf(u.def.heal_shield_cap_fraction, 0.0, 1.0),
		"duration": u.def.heal_shield_duration, "cleanse": cleanse,
		"immunity": u.def.control_immunity_duration})


func _apply_pending_protection() -> void:
	# Resolve each target's lower-cap sources before higher-cap sources. Each
	# contribution still has its own cap, and no source may shrink protection.
	# A fixed order prevents a Medic/self-shield combination changing strength
	# when its sources happen to have different unit ids or enqueue order.
	_pending_protection.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["target_id"]) != int(b["target_id"]):
			return int(a["target_id"]) < int(b["target_id"])
		if float(a["cap"]) != float(b["cap"]):
			return float(a["cap"]) < float(b["cap"])
		return int(a["attacker_id"]) < int(b["attacker_id"]))
	for protection in _pending_protection:
		var target := units[int(protection["target_id"])]
		# A weaker shield source cannot shrink a stronger existing shield.
		var before := target.shield
		target.shield = maxf(before, minf(before + float(protection["amount"]), float(protection["cap"])))
		target.shield_timer = maxf(target.shield_timer, float(protection["duration"]))
		events.append({"type": "shield", "attacker_id": protection["attacker_id"],
			"target_id": target.id, "amount": target.shield - before,
			"shield": target.shield, "duration": target.shield_timer})
		if protection["cleanse"]:
			var cleansed := int(target.stagger_timer > 0.0) + int(target.slow_timer > 0.0) + int(target.suppression_timer > 0.0)
			target.stagger_timer = 0.0
			target.slow_timer = 0.0
			target.slow_fraction = 0.0
			target.suppression_timer = 0.0
			target.suppression_fraction = 0.0
			target.control_immunity_timer = maxf(target.control_immunity_timer, float(protection["immunity"]))
			events.append({"type": "cleanse", "attacker_id": protection["attacker_id"],
				"target_id": target.id, "amount": cleansed, "duration": target.control_immunity_timer})
	_pending_protection.clear()


func _queue_status(effect: String, attacker_id: int, target_id: int, amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	_pending_statuses.append({"effect": effect, "attacker_id": attacker_id,
		"target_id": target_id, "amount": amount, "duration": duration})


## Hostile effects resolve only after all attack decisions and protective
## cleanses. Strongest magnitude and longest duration win, without addition.
func _apply_pending_statuses() -> void:
	for status in _pending_statuses:
		var target := units[int(status["target_id"])]
		var effect: String = status["effect"]
		if effect != "mark" and target.control_immunity_timer > 0.0:
			continue
		var amount: float = status["amount"]
		var duration: float = status["duration"]
		var changed := false
		match effect:
			"stagger":
				changed = true
				target.stagger_timer = maxf(target.stagger_timer, duration)
			"slow":
				changed = target.slow_timer <= 0.0 or amount > target.slow_fraction
				target.slow_fraction = maxf(target.slow_fraction, clampf(amount, 0.0, 1.0))
				target.slow_timer = maxf(target.slow_timer, duration)
			"suppression":
				changed = true
				target.suppression_fraction = maxf(target.suppression_fraction, clampf(amount, 0.0, 1.0))
				target.suppression_timer = maxf(target.suppression_timer, duration)
			"mark":
				changed = true
				target.vulnerability_fraction = maxf(target.vulnerability_fraction, amount)
				target.vulnerability_timer = maxf(target.vulnerability_timer, duration)
		if changed:
			events.append({"type": effect, "attacker_id": status["attacker_id"],
				"target_id": target.id, "amount": amount, "duration": duration})
	_pending_statuses.clear()


## Rolled per landed hit, using only the seeded sim RNG. New stagger cannot
## suppress another unit's attack decision from this same tick.
func _maybe_stagger(u: SimUnit, target: SimUnit) -> void:
	if u.def.stagger_min_level <= 0 or u.level < u.def.stagger_min_level:
		return
	if rng.randf() < u.def.stagger_chance:
		_queue_status("stagger", u.id, target.id, 1.0, u.def.stagger_duration)


## Firestorm (UnitDefinition.firepatch_min_level+): a landed splash attack
## also leaves a burning ground patch at the impact point, independent of
## the direct splash hit already applied by the caller. Deterministic (no
## rng) -- unlike stagger, this always fires once the level gate is met, so
## it doesn't need a chance roll.
func _maybe_spawn_fire_patch(u: SimUnit, impact_pos: Vector2) -> void:
	if u.def.firepatch_min_level <= 0 or u.level < u.def.firepatch_min_level:
		return
	_fire_patches.append({
		"pos": impact_pos,
		"remaining": u.def.firepatch_duration,
		"team": u.team,
		"dps": u.def.firepatch_dps * u.power_multiplier * _outgoing_damage_multiplier(u),
		"attacker_id": u.id,
		"slow_fraction": u.def.firepatch_slow_fraction if u.def.firepatch_slow_min_level > 0 and u.level >= u.def.firepatch_slow_min_level else 0.0,
		"slow_duration": u.def.firepatch_slow_duration,
		"radius": u.def.firepatch_radius,
	})
	events.append({"type": "fire_patch_spawn", "attacker_id": u.id, "pos": impact_pos,
		"duration": u.def.firepatch_duration, "radius": u.def.firepatch_radius, "team": u.team})


## Ticks every active Firestorm patch: damages any enemy standing in it this
## tick, then ages it out. Filtered in place rather than removed by index
## during iteration, same reason _apply_damage() et al. snapshot first.
func _tick_fire_patches() -> void:
	var still_active: Array = []
	for patch in _fire_patches:
		# A partial last tick contributes only its remaining lifetime. A zero
		# duration patch never deals damage.
		var active_delta := minf(maxf(float(patch["remaining"]), 0.0), TICK_DELTA)
		if active_delta <= 0.0:
			continue
		var damage: float = patch["dps"] * active_delta
		for other in units:
			if not other.alive or other.team == patch["team"]:
				continue
			if damage > 0.0 and other.pos.distance_to(patch["pos"]) <= patch["radius"]:
				_queue_damage(other, damage)
				_queue_status("slow", int(patch.get("attacker_id", -1)), other.id,
					float(patch.get("slow_fraction", 0.0)), float(patch.get("slow_duration", 0.0)))
		patch["remaining"] = maxf(0.0, float(patch["remaining"]) - active_delta)
		if patch["remaining"] > 0.0:
			still_active.append(patch)
	_fire_patches = still_active


## Berserk (UnitDefinition.berserk_min_level+): attack interval shortens as
## this unit's OWN hp drops, linearly from 1.0x at full hp to
## berserk_max_speed_mult at 0 hp. Below the unlocked level, or for any unit
## without the ability (berserk_min_level == 0), this is just def.attack_interval().
func _effective_attack_interval(u: SimUnit) -> float:
	var base := u.def.attack_interval()
	if u.def.berserk_min_level <= 0 or u.level < u.def.berserk_min_level:
		return base
	var missing_frac := 1.0 - u.hp_fraction()
	return base * lerpf(1.0, u.def.berserk_max_speed_mult, missing_frac)


func _tick_status_effects() -> void:
	for u in units:
		if not u.alive:
			continue
		u.stagger_timer = maxf(0.0, u.stagger_timer - TICK_DELTA)
		u.control_immunity_timer = maxf(0.0, u.control_immunity_timer - TICK_DELTA)
		u.slow_timer = maxf(0.0, u.slow_timer - TICK_DELTA)
		u.suppression_timer = maxf(0.0, u.suppression_timer - TICK_DELTA)
		u.vulnerability_timer = maxf(0.0, u.vulnerability_timer - TICK_DELTA)
		if u.slow_timer <= 0.0:
			u.slow_fraction = 0.0
		if u.suppression_timer <= 0.0:
			u.suppression_fraction = 0.0
		if u.vulnerability_timer <= 0.0:
			u.vulnerability_fraction = 0.0
		if u.shield_timer > 0.0:
			u.shield_timer = maxf(0.0, u.shield_timer - TICK_DELTA)
			if u.shield_timer <= 0.0:
				u.shield = 0.0
				events.append({"type": "shield_expire", "unit_id": u.id})


func _movement_speed(u: SimUnit) -> float:
	return u.def.move_speed * (1.0 - clampf(u.slow_fraction, 0.0, 1.0)) if u.slow_timer > 0.0 else u.def.move_speed


## Support units only: a Mercy-style token self-defense — fires a weak shot at the
## nearest threat INSTEAD of healing this cooldown, if that threat has closed to
## self_defense_range. One action per cooldown, never both in the same tick, on
## purpose: the point isn't a free hybrid heal+damage kit, it's making sure no hand
## is mathematically incapable of ever winning (a stacked-support hand was
## previously a hard 0% — see the roster-expansion balance pass) while staying
## clearly a healer first. self_defense_range is deliberately short (well inside
## retreat_range) so this only fires as a last resort while already fleeing, not as
## a proactive secondary attack.
func _try_self_defense(u: SimUnit) -> bool:
	if u.def.self_defense_damage <= 0.0 or u.threat_id < 0:
		return false
	var threat := units[u.threat_id]
	if not threat.alive or u.pos.distance_to(threat.pos) > u.def.self_defense_range:
		return false
	_queue_attack_hit(u, threat, u.def.self_defense_damage * u.power_multiplier)
	u.attack_cooldown = _effective_attack_interval(u)
	events.append({"type": "attack", "attacker_id": u.id, "target_id": threat.id})
	return true


## Every unit's move is computed from a single pre-tick position snapshot and applied
## only after all units have decided, so order in the `units` array can't matter.
## (Reading a target's *already-moved* position mid-loop was the actual cause of a
## confirmed Team-A-always-wins bug in the Trooper-vs-Enforcer matchup: whichever
## team was iterated first got to move using stale target data while the other team
## effectively got a free look at the first team's post-move position. See the
## balance report for how this was diagnosed.)
func _move() -> void:
	var new_positions: Array[Vector2] = []
	for u in units:
		new_positions.append(u.pos)

	for u in units:
		if not u.alive:
			continue
		if u.stagger_timer > 0.0:
			continue

		if u.def.is_support:
			_move_support(u, new_positions)
			continue

		if u.target_id < 0:
			continue
		var target := units[u.target_id]
		if not target.alive:
			continue

		var to_target := target.pos - u.pos
		var dist := to_target.length()
		var dir: Vector2
		if dist > 0.0001:
			dir = to_target / dist
		else:
			# Deterministic fallback when exactly coincident.
			dir = Vector2.RIGHT if u.team == 0 else Vector2.LEFT

		var step := _movement_speed(u) * TICK_DELTA
		if dist > u.def.preferred_range:
			new_positions[u.id] = u.pos + dir * step
		elif dist < u.def.retreat_range:
			new_positions[u.id] = _retreat_position(u, -dir, step, target.pos)
		# else: hold position

	for u in units:
		u.pos = new_positions[u.id]


## Support units don't fight — they flee the nearest enemy (using retreat_range
## against that THREAT, not against the ally they're healing) and otherwise stay
## in heal range of whoever needs it most. Self-preservation always wins over
## healing: an already-hurt medic that keeps closing on its patient instead of
## backing off is just a free kill.
func _move_support(u: SimUnit, new_positions: Array[Vector2]) -> void:
	var step := _movement_speed(u) * TICK_DELTA

	if u.threat_id >= 0:
		var threat := units[u.threat_id]
		if threat.alive:
			var threat_dist := u.pos.distance_to(threat.pos)
			if threat_dist < u.def.retreat_range:
				var away := u.pos - threat.pos
				var away_dir: Vector2
				if away.length() > 0.0001:
					away_dir = away.normalized()
				else:
					away_dir = Vector2.RIGHT if u.team == 0 else Vector2.LEFT
				new_positions[u.id] = _retreat_position(u, away_dir, step, threat.pos)
				return

	if u.target_id < 0:
		_advance_on_threat_if_idle(u, new_positions, step)
		return
	var target := units[u.target_id]
	if not target.alive:
		_advance_on_threat_if_idle(u, new_positions, step)
		return

	var to_target := target.pos - u.pos
	var dist := to_target.length()
	if dist > u.def.preferred_range:
		var dir := to_target / dist if dist > 0.0001 else (Vector2.RIGHT if u.team == 0 else Vector2.LEFT)
		new_positions[u.id] = u.pos + dir * step
	# else: hold at heal range


## Nothing to heal and the nearest enemy isn't close enough to trigger a
## retreat -- previously this meant _move_support() just returned and the
## unit froze in place, permanently, since a support has no other reason to
## move. Two supports left alone on opposite sides (e.g. the last unit each
## side, after everything else traded kills) both hit this exact state
## simultaneously and neither would ever close the distance -- a genuine
## stalemate that ran to the 90s MATCH_TIMEOUT instead of resolving
## (reported directly: "if three units are left and one of them is medic on
## each side, the battle goes on forever"). A cautious HALF-speed advance
## toward the threat breaks the freeze without turning a medic into an
## aggressor -- it still retreats immediately once inside retreat_range (the
## branch above this runs every tick, so that check still fires the moment
## it gets close), so this only ever closes the gap as far as retreat_range
## allows, no further.
func _advance_on_threat_if_idle(u: SimUnit, new_positions: Array[Vector2], step: float) -> void:
	if u.threat_id < 0:
		return
	var threat := units[u.threat_id]
	if not threat.alive:
		return
	var to_threat := threat.pos - u.pos
	var dist := to_threat.length()
	if dist <= u.def.retreat_range:
		return
	var dir := to_threat / dist if dist > 0.0001 else (Vector2.RIGHT if u.team == 0 else Vector2.LEFT)
	new_positions[u.id] = u.pos + dir * step * 0.5


## Retreat directions to try, in order: straight away first, then progressively more
## sideways. Fixed order + strict `>` scoring means ties resolve to the straightest
## option, which keeps this deterministic.
##
## Signs must be mirrored per team (see _retreat_position): reflecting a scene across
## the X axis flips the sense of rotation, so applying the identical signed sequence
## to both teams is NOT symmetric — it gives Team A a real tactical edge in any
## tie-broken, wall-adjacent retreat. Confirmed empirically: pure Trooper vs pure
## Enforcer flipped winner purely based on which hand was passed as Team A, before
## this was mirrored.
const RETREAT_ANGLES: Array = [0.0, -30.0, 30.0, -60.0, 60.0, -90.0, 90.0, -120.0, 120.0]


## Picks where a retreating unit actually goes. Moving straight away from the threat
## is preferred, but a unit backed against a wall would otherwise just pin itself
## there and die — so it slides along the wall instead. This is what makes the design
## doc's kiting behavior possible at all; without it Trooper can never out-space
## Enforcer, because it spawns only 2.5m from its own back wall.
func _retreat_position(u: SimUnit, away_dir: Vector2, step: float, threat_pos: Vector2) -> Vector2:
	var best_pos := u.pos
	var best_score := -INF
	# Team 1 is the X-mirror of team 0, so its angle sequence must be negated to stay
	# a true mirror image rather than a 180-degree-rotated one.
	var angle_sign := -1.0 if u.team == 1 else 1.0

	for base_angle_deg in RETREAT_ANGLES:
		var angle_deg: float = base_angle_deg * angle_sign
		var candidate := u.pos + away_dir.rotated(deg_to_rad(angle_deg)) * step
		if candidate.x < UNIT_RADIUS or candidate.x > ARENA_WIDTH - UNIT_RADIUS:
			continue
		if candidate.y < UNIT_RADIUS or candidate.y > ARENA_DEPTH - UNIT_RADIUS:
			continue
		var score := candidate.distance_squared_to(threat_pos)
		if score > best_score:
			best_score = score
			best_pos = candidate

	return best_pos


## Keeps units from stacking into one blob. All pushes are computed from a single
## pre-resolution position snapshot and summed, then applied once at the end — pairs
## are still visited in id order, but that order can no longer leak into the result,
## since earlier pairs no longer mutate positions that later pairs read. (Applying
## each pair's push immediately, as this used to, made whichever team held the lower
## unit ids — always Team A, since it spawns first — get pushed using positions the
## other team hadn't been displaced from yet, a real and confirmed source of a
## Team-A/Team-B win bias independent of unit stats. See the balance report.)
func _resolve_separation() -> void:
	var min_dist := UNIT_RADIUS * 2.0
	var push_accum: Array[Vector2] = []
	for i in range(units.size()):
		push_accum.append(Vector2.ZERO)

	for i in range(units.size()):
		var a := units[i]
		if not a.alive:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if not b.alive:
				continue
			var delta := b.pos - a.pos
			var d := delta.length()
			if d >= min_dist:
				continue
			var push: Vector2
			if d > 0.0001:
				push = (delta / d) * ((min_dist - d) * 0.5)
			else:
				push = Vector2(0.0, 0.005)
			push_accum[i] -= push
			push_accum[j] += push

	for i in range(units.size()):
		units[i].pos += push_accum[i]


func _clamp_to_arena() -> void:
	for u in units:
		if not u.alive:
			continue
		u.pos.x = clampf(u.pos.x, UNIT_RADIUS, ARENA_WIDTH - UNIT_RADIUS)
		u.pos.y = clampf(u.pos.y, UNIT_RADIUS, ARENA_DEPTH - UNIT_RADIUS)


func _apply_damage() -> void:
	for u in units:
		if not u.alive:
			continue
		if u.pending_heal > 0.0:
			u.hp = minf(u.hp + u.pending_heal, u.max_hp())
			u.pending_heal = 0.0
		if u.pending_damage > 0.0:
			var shieldable := maxf(0.0, u.pending_damage - u.pending_shield_bypass)
			var absorbed := minf(u.shield, shieldable)
			u.shield -= absorbed
			u.hp -= u.pending_damage - absorbed
			u.pending_damage = 0.0
			if absorbed > 0.0:
				events.append({"type": "shield_hit", "target_id": u.id, "amount": absorbed, "shield": u.shield})
			if u.shield <= 0.0:
				u.shield_timer = 0.0
			if u.hp <= 0.0:
				u.hp = 0.0
				u.alive = false
				u.target_id = -1
				events.append({"type": "death", "unit_id": u.id})
		u.pending_shield_bypass = 0.0


## Shared by both the real end-of-match timeout and the stalemate detector
## below -- same tiebreak either way, just triggered at a different point.
func _hp_tiebreak() -> Result:
	var a_hp := total_hp(0)
	var b_hp := total_hp(1)
	if a_hp > b_hp:
		return Result.TEAM_A
	elif b_hp > a_hp:
		return Result.TEAM_B
	return Result.DRAW


func _evaluate_result() -> void:
	var a_alive := alive_count(0)
	var b_alive := alive_count(1)

	if a_alive == 0 and b_alive == 0:
		result = Result.DRAW
	elif b_alive == 0:
		result = Result.TEAM_A
	elif a_alive == 0:
		result = Result.TEAM_B
	elif elapsed >= MATCH_TIMEOUT:
		result = _hp_tiebreak()
	elif elapsed - _last_action_elapsed >= STALEMATE_TIMEOUT:
		result = _hp_tiebreak()


func alive_count(team: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.team == team:
			n += 1
	return n


func total_hp(team: int) -> float:
	var sum := 0.0
	for u in units:
		if u.alive and u.team == team:
			sum += u.hp
	return sum
