extends SceneTree
## Deterministic, in-memory regression scenarios. No profile/autoload writes.
## Run with: godot --headless --script tools/sim_regression_test.gd

const EPSILON := 0.00001
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_test_simultaneous_stagger()
	_test_stagger_gates_and_refresh()
	_test_stagger_expiry()
	_test_fire_patch_lifetime_and_teams()
	_test_zero_duration_patch()
	_test_setup_resets_transient_state()
	_test_round_state_reuse()
	_test_repeated_draws_terminate()
	_test_damage_over_time_activity()
	_test_empty_patch_does_not_delay_stalemate()
	_test_berserk_level_gate()
	_test_lunge_decisions_use_snapshot()
	_test_lunge_reset_and_bounds()
	_test_shield_bypass_bounds_and_order()
	_test_shield_bypass_burst_splash_and_chain()
	_test_shield_bypass_reset_and_simultaneous_death()
	_test_mixed_shield_caps_and_queue_order()
	_test_mixed_shields_in_combat()
	_test_seeded_replay()
	if _failures.is_empty():
		print("PASS: %d simulation regression checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		printerr("%d of %d simulation regression checks failed" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON,
		"%s (actual=%.9f expected=%.9f)" % [message, actual, expected])


func _fighter() -> UnitDefinition:
	var unit := UnitDefinition.new()
	unit.hp = 100.0
	unit.damage_per_hit = 10.0
	unit.attacks_per_second = 1.0
	unit.preferred_range = 50.0
	unit.move_speed = 0.0
	return unit


func _passive() -> UnitDefinition:
	var unit := _fighter()
	unit.preferred_range = 0.0
	return unit


func _staggerer(duration: float = 0.6) -> UnitDefinition:
	var unit := _fighter()
	unit.stagger_min_level = 2
	unit.stagger_chance = 1.0
	unit.stagger_duration = duration
	return unit


func _burner(duration: float) -> UnitDefinition:
	var unit := _fighter()
	unit.splash_radius = 0.5
	unit.firepatch_min_level = 2
	unit.firepatch_dps = 12.0
	unit.firepatch_duration = duration
	unit.firepatch_radius = 2.0
	return unit


func _event_count(sim: BattleSim, type: String) -> int:
	var count := 0
	for event in sim.events:
		if event["type"] == type:
			count += 1
	return count


func _test_simultaneous_stagger() -> void:
	var def := _staggerer()
	var sim := BattleSim.new()
	sim.setup([def], [def], 17, [], [], [2], [2])
	sim.tick()
	_near(sim.units[0].hp, 90.0, "Team B retaliates on the tick it is staggered")
	_near(sim.units[1].hp, 90.0, "Team A and Team B resolve simultaneous damage equally")
	_expect(_event_count(sim, "attack") == 2, "Both simultaneous attacks emit events")
	_expect(_event_count(sim, "stagger") == 2, "Both simultaneous staggers emit events")
	_near(sim.units[0].stagger_timer, 0.6, "Team A receives stagger")
	_near(sim.units[1].stagger_timer, 0.6, "Team B receives stagger")
	sim.tick()
	_expect(_event_count(sim, "attack") == 0, "Existing stagger suppresses subsequent attacks")


func _test_stagger_gates_and_refresh() -> void:
	var def := _staggerer()
	var sim := BattleSim.new()
	sim.setup([def], [_passive()], 23, [], [], [1], [1])
	sim.tick()
	_near(sim.units[1].stagger_timer, 0.0, "Stagger is disabled below its level gate")
	def.stagger_chance = 0.0
	sim.setup([def], [_passive()], 23, [], [], [2], [1])
	sim.tick()
	_near(sim.units[1].stagger_timer, 0.0, "Zero stagger chance never triggers")

	sim.setup([_staggerer(0.2), _staggerer(0.4)], [_passive()], 31, [], [], [2, 2], [1])
	sim.tick()
	_near(sim.units[2].stagger_timer, 0.4, "Simultaneous staggers use longest duration, not a sum")

	sim.setup([_staggerer(0.2)], [_passive()], 31, [], [], [2], [1])
	sim.units[1].stagger_timer = 0.5
	sim.tick()
	_near(sim.units[1].stagger_timer, 0.5 - BattleSim.TICK_DELTA,
		"Shorter incoming stagger does not shorten an active stagger")


func _test_stagger_expiry() -> void:
	var sim := BattleSim.new()
	sim.setup([_fighter()], [_fighter()], 37)
	var victim := sim.units[1]
	victim.attack_cooldown = 0.0
	victim.stagger_timer = BattleSim.TICK_DELTA * 2.5
	sim.tick()
	_near(sim.units[0].hp, 100.0, "Stagger blocks attack before expiry")
	sim.tick()
	_near(sim.units[0].hp, 100.0, "Stagger remains active for its remaining partial tick")
	sim.tick()
	_near(victim.stagger_timer, 0.0, "Stagger clamps to zero on expiry")
	_near(sim.units[0].hp, 90.0, "Attack resumes when stagger expires")


func _test_fire_patch_lifetime_and_teams() -> void:
	var duration := BattleSim.TICK_DELTA * 2.5
	var sim := BattleSim.new()
	sim.setup([_burner(duration)], [_passive(), _passive()], 41, [], [], [2], [1, 1])
	sim.units[0].pos = Vector2(10.0, 7.0)
	sim.units[1].pos = Vector2(11.0, 7.0)
	sim.units[2].pos = Vector2(18.0, 7.0)
	for _i in range(3):
		sim.tick()
	_near(sim.units[1].hp, 100.0 - 10.0 - 12.0 * duration,
		"Partial final fire tick deals only damage for the remaining duration")
	_near(sim.units[0].hp, 100.0, "Fire patch never damages its owner's team")
	_near(sim.units[2].hp, 100.0, "Fire patch excludes enemies outside its radius")
	_expect(sim._fire_patches.is_empty(), "Fire patch expires after its configured duration")
	var hp_after_expiry := sim.units[1].hp
	sim.tick()
	_near(sim.units[1].hp, hp_after_expiry, "Expired fire patch deals no more damage")

	sim.setup([_burner(duration)], [_passive()], 41, [], [], [1], [1])
	sim.tick()
	_expect(sim._fire_patches.is_empty(), "Firestorm is disabled below its level gate")
	_near(sim.units[1].hp, 90.0, "Below the gate only direct damage lands")


func _test_zero_duration_patch() -> void:
	var sim := BattleSim.new()
	sim.setup([_burner(0.0)], [_passive()], 43, [], [], [2], [1])
	sim.tick()
	_near(sim.units[1].hp, 90.0, "Zero-duration patch adds no damage")
	_expect(sim._fire_patches.is_empty(), "Zero-duration patch expires immediately")


func _test_setup_resets_transient_state() -> void:
	var def := _burner(3.0)
	var passive := _passive()
	var sim := BattleSim.new()
	sim.setup([def], [passive], 47, [], [], [2], [1])
	sim.tick()
	_expect(not sim._fire_patches.is_empty(), "Reuse fixture creates an active hazard")
	sim.setup([def], [passive], 47, [], [], [1], [1])
	var fresh := BattleSim.new()
	fresh.setup([def], [passive], 47, [], [], [1], [1])
	_expect(_snapshot(sim) == _snapshot(fresh), "Reused simulation setup equals fresh setup")
	sim.tick()
	fresh.tick()
	_expect(_snapshot(sim) == _snapshot(fresh), "Prior hazards cannot damage a reused simulation")


func _test_round_state_reuse() -> void:
	var hand: Array[UnitDefinition] = [_fighter()]
	var rounds := RoundState.new()
	rounds.init(hand, hand, 53)
	rounds.record_round_result(BattleSim.Result.DRAW)
	rounds.record_round_result(BattleSim.Result.DRAW)
	_expect(rounds.draw_retry == 2, "Round reuse fixture advances draw retry")
	rounds.init(hand, hand, 53)
	_expect(rounds.draw_retry == 0, "New match clears prior draw retry")
	_expect(rounds.current_seed() == 1053, "New match's first seed is independent of prior draws")
	_expect(not rounds.draw_round_resolved, "New match clears a prior draw resolution")


func _test_repeated_draws_terminate() -> void:
	var hand: Array[UnitDefinition] = [_fighter()]
	var rounds := RoundState.new()
	rounds.init(hand, hand, 54)
	for resolved in range(RoundState.LIVES_PER_SIDE):
		for retry in range(RoundState.MAX_DRAW_RETRIES):
			rounds.record_round_result(BattleSim.Result.DRAW)
			_expect(not rounds.draw_round_resolved, "Draw retry does not prematurely consume a life")
			_expect(rounds.lives_a == RoundState.LIVES_PER_SIDE - resolved, "Lives remain intact within draw retry budget")
		rounds.record_round_result(BattleSim.Result.DRAW)
		_expect(rounds.draw_round_resolved, "Fifth exact draw resolves the current round")
		_expect(rounds.lives_a == rounds.lives_b and rounds.lives_a == RoundState.LIVES_PER_SIDE - resolved - 1,
			"Resolved draw consumes one life on both sides without side bias")
		_expect(rounds.draw_retry == 0, "Resolved draw resets its retry counter")
		if not rounds.is_match_over():
			rounds.advance_round_number()
	_expect(rounds.is_match_over() and rounds.winner_team() == -1, "Perfectly mirrored matches terminate as draws")


func _test_damage_over_time_activity() -> void:
	var def := _burner(13.0)
	def.attacks_per_second = 0.01
	def.damage_per_hit = 0.0
	def.firepatch_dps = 1.0
	var sim := BattleSim.new()
	sim.setup([def], [_passive()], 59, [], [], [2], [1])
	for _i in range(13 * 60 + 1):
		sim.tick()
	_expect(sim.result == BattleSim.Result.IN_PROGRESS,
		"Ongoing nonlethal fire damage prevents a false stalemate after twelve seconds")
	_near(sim.units[1].hp, 87.0, "Long fire patch deals exactly DPS times duration")
	_expect(sim._fire_patches.is_empty(), "Long fire patch still expires")
	_expect(sim._last_action_elapsed >= 13.0, "Damage over time updates combat activity")
	sim.run_to_completion()
	_expect(sim.result == BattleSim.Result.TEAM_A, "Normal HP tiebreak resumes after hazard expires")
	_expect(sim.elapsed >= 25.0 and sim.elapsed < 25.1,
		"Stalemate timeout starts after the last damaging hazard tick")


func _test_empty_patch_does_not_delay_stalemate() -> void:
	var def := _burner(30.0)
	def.attacks_per_second = 0.01
	def.damage_per_hit = 0.0
	var sim := BattleSim.new()
	sim.setup([def], [_passive()], 61, [], [], [2], [1])
	sim.tick()
	sim.units[1].pos = Vector2(22.0, 2.0)
	sim.run_to_completion()
	_expect(sim.elapsed >= 12.0 and sim.elapsed < 12.1,
		"An active patch with no victims does not postpone a genuine stalemate")


func _test_berserk_level_gate() -> void:
	var def := _fighter()
	def.berserk_min_level = 3
	def.berserk_max_speed_mult = 0.6
	var sim := BattleSim.new()
	sim.setup([def], [_passive()], 67, [], [], [2], [1])
	var unit := sim.units[0]
	unit.hp = unit.max_hp() * 0.5
	_near(sim._effective_attack_interval(unit), 1.0, "Berserk is disabled below its level gate")
	unit.level = 3
	_near(sim._effective_attack_interval(unit), 0.8, "Berserk scales with missing health")
	unit.hp = unit.max_hp()
	_near(sim._effective_attack_interval(unit), 1.0, "Berserk returns to base interval at full health")


func _test_lunge_decisions_use_snapshot() -> void:
	var lunger: UnitDefinition = UnitDatabase.PHASEBLADE.duplicate()
	lunger.move_speed = 0.0
	var defender := _fighter()
	defender.preferred_range = 1.1
	for side in [0, 1]:
		var sim := BattleSim.new()
		if side == 0:
			sim.setup([lunger], [defender], 69, [], [], [2], [1])
		else:
			sim.setup([defender], [lunger], 69, [], [], [1], [2])
		var actor := sim.units[side]
		var target := sim.units[1 - side]
		actor.pos = Vector2(10.0 if side == 0 else 14.0, 7.0)
		target.pos = Vector2(11.5 if side == 0 else 12.5, 7.0)
		actor.attacks_fired = 2
		sim.tick()
		_near(actor.hp, lunger.hp, "Lunge cannot enable the opponent's already-decided attack on side %d" % side)
		_near(actor.pos.distance_to(target.pos), 1.0, "Lunge stops at contact symmetrically on side %d" % side)
		_expect(_event_count(sim, "attack") == 1, "Only the pre-lunge in-range attacker fires")
		_expect(sim._pending_lunges.is_empty(), "Lunge queue drains before tick completion")
		sim.tick()
		_near(actor.hp, lunger.hp - 10.0, "Opponent can attack from the new range next tick")


func _test_lunge_reset_and_bounds() -> void:
	var def := _fighter()
	def.special_attack_min_level = 2
	def.special_attack_every = 1
	def.special_lunge_distance = 50.0
	var sim := BattleSim.new()
	sim.setup([def], [_passive()], 70, [], [], [2], [1])
	sim.units[0].pos = Vector2(20.0, 7.0)
	sim.units[1].pos = Vector2(23.5, 7.0)
	sim.tick()
	_near(sim.units[0].pos.x, 22.5, "Oversized lunge cannot cross its target or arena edge")
	sim._queue_lunge(sim.units[0], sim.units[1])
	sim.units[0].pos = Vector2(10.0, 7.0)
	sim._queue_lunge(sim.units[0], sim.units[1])
	_expect(not sim._pending_lunges.is_empty(), "Reset fixture creates a deferred lunge")
	sim.setup([def], [_passive()], 70, [], [], [1], [1])
	_expect(sim._pending_lunges.is_empty(), "Setup clears deferred movement from a previous match")


func _piercer() -> UnitDefinition:
	var def := _fighter()
	def.damage_per_hit = 20.0
	def.special_attack_min_level = 2
	def.special_attack_every = 1
	def.special_shield_bypass_fraction = 0.5
	return def


func _test_shield_bypass_bounds_and_order() -> void:
	for fraction in [-0.5, 0.0, 0.5, 1.0, 1.5]:
		var def := _piercer()
		def.special_shield_bypass_fraction = fraction
		var sim := BattleSim.new()
		sim.setup([def], [_passive()], 281, [], [], [2], [1])
		sim.units[1].shield = 100.0
		sim.units[1].shield_timer = 3.0
		sim.tick()
		var bounded := clampf(fraction, 0.0, 1.0)
		_near(sim.units[1].hp, 100.0 - 20.0 * bounded, "Generic shield bypass clamps fraction %.1f" % fraction)
		_near(sim.units[1].shield, 100.0 - 20.0 * (1.0 - bounded), "Clamped damage is partitioned without duplication")
		_near(sim.units[1].pending_shield_bypass, 0.0, "Resolved bypass never persists to a later tick")
	for side in [0, 1]:
		for reverse in [false, true]:
			var hand: Array[UnitDefinition] = []
			hand.assign([_fighter(), _piercer()] if reverse else [_piercer(), _fighter()])
			var sim := BattleSim.new()
			if side == 0:
				sim.setup(hand, [_passive()], 283, [], [], [2, 2], [1])
			else:
				sim.setup([_passive()], hand, 283, [], [], [1], [2, 2])
			var target := sim.units[2 if side == 0 else 0]
			target.shield = 14.0
			target.shield_timer = 3.0
			sim.tick()
			_near(target.hp, 84.0, "Mixed piercing/ordinary hits sum before shields: side %d reverse %s" % [side, reverse])
			_near(target.shield, 0.0, "Mixed hits consume the same shield regardless of attacker order")
			_near(target.pending_damage, 0.0, "Resolution clears total queued damage")
			_near(target.pending_shield_bypass, 0.0, "Resolution clears queued bypass with mixed hits")


func _test_shield_bypass_burst_splash_and_chain() -> void:
	for splash in [false, true]:
		var def := _piercer()
		def.special_attack_hits = 2
		if splash:
			def.splash_radius = 2.0
		else:
			def.special_chain_targets = 1
			def.special_chain_damage_mult = 0.25
			def.special_chain_radius = 2.0
		var sim := BattleSim.new()
		sim.setup([def], [_passive(), _passive()], 289, [], [], [2], [1, 1])
		sim.units[0].pos = Vector2(8.0, 7.0)
		sim.units[1].pos = Vector2(12.0, 7.0)
		sim.units[2].pos = Vector2(13.0, 7.0)
		for target in [sim.units[1], sim.units[2]]:
			target.shield = 100.0
			target.shield_timer = 3.0
		sim.tick()
		_near(sim.units[1].hp, 80.0, "Each primary special burst hit carries its bypass portion")
		_near(sim.units[1].shield, 80.0, "Primary shield absorbs the remaining burst damage")
		_near(sim.units[2].hp, 80.0 if splash else 97.5, "Special splash/chain secondary receives proportional bypass")
		_near(sim.units[2].shield, 80.0 if splash else 97.5, "Secondary shields absorb their proportional remainder")
		_expect(sim.units[0].attacks_fired == 1, "Burst/splash/chain bypass does not advance attack cadence")


func _test_shield_bypass_reset_and_simultaneous_death() -> void:
	var def := _piercer()
	var passive := _passive()
	var sim := BattleSim.new()
	sim.setup([def], [passive], 293, [], [], [2], [1])
	sim._queue_attack_hit(sim.units[0], sim.units[1], 20.0, true)
	_near(sim.units[1].pending_damage, 20.0, "Queued total retains the complete hit")
	_near(sim.units[1].pending_shield_bypass, 10.0, "Bypass accumulator is a subset of queued total")
	_near(sim.units[1].hp, 100.0, "Queueing bypass does not mutate HP before resolution")
	sim.setup([def], [passive], 293, [], [], [2], [1])
	var fresh := BattleSim.new()
	fresh.setup([def], [passive], 293, [], [], [2], [1])
	_expect(_snapshot(sim) == _snapshot(fresh), "Setup discards queued piercing damage from the previous match")
	sim.tick()
	fresh.tick()
	_expect(_snapshot(sim) == _snapshot(fresh), "Reused piercing simulation replays like a fresh simulation")
	var hp_after_tick := sim.units[1].hp
	sim._apply_damage()
	_near(sim.units[1].hp, hp_after_tick, "Applying damage again cannot repeat a bypass hit")
	def.hp = 10.0
	def.special_shield_bypass_fraction = 1.0
	sim.setup([def], [def], 307, [], [], [2], [2])
	for unit in sim.units:
		unit.shield = 100.0
		unit.shield_timer = 3.0
	sim.tick()
	_expect(sim.result == BattleSim.Result.DRAW, "Lethal shield bypass preserves both same-tick attacks")
	_expect(_event_count(sim, "attack") == 2 and _event_count(sim, "death") == 2,
		"Both shielded combatants attack and die simultaneously")
	for unit in sim.units:
		_near(unit.hp, 0.0, "Lethal piercing damage clamps HP to zero")
		_near(unit.shield, 100.0, "Fully piercing damage leaves shield intact even on death")
		_near(unit.pending_shield_bypass, 0.0, "Death leaves no queued bypass")


func _shield_guard() -> UnitDefinition:
	var def := _fighter()
	def.hp = 480.0
	def.special_attack_min_level = 2
	def.special_attack_every = 1
	def.self_shield_min_level = 2
	def.self_shield_amount = 36.0
	def.self_shield_cap_fraction = 0.3
	def.self_shield_duration = 2.5
	return def


func _shield_healer() -> UnitDefinition:
	var def := _fighter()
	def.is_support = true
	def.damage_per_hit = 5.0
	def.heal_shield_min_level = 2
	def.heal_shield_amount = 21.0
	def.heal_shield_cap_fraction = 0.25
	def.heal_shield_duration = 3.0
	def.shield_cleanse_min_level = 3
	def.control_immunity_duration = 0.75
	return def


func _test_mixed_shield_caps_and_queue_order() -> void:
	# Values match an equal-tier Lv2 Bulwark and Medic. Same target, amounts
	# and caps must not become 126 vs 144 merely by reversing queued sources.
	var cases: Array = [
		[0.0, 36.0, 21.0, 0.25, 57.0],
		[90.0, 36.0, 21.0, 0.25, 144.0],
		[130.0, 36.0, 21.0, 0.25, 144.0],
		[160.0, 36.0, 21.0, 0.25, 160.0],
		[0.0, 5.0, 200.0, 0.25, 125.0],
		[130.0, 36.0, 21.0, 0.3, 144.0],
	]
	for entry in cases:
		var reference: Array = []
		for reverse in [false, true]:
			var guard := _shield_guard()
			var healer := _shield_healer()
			guard.self_shield_amount = entry[1]
			healer.heal_shield_amount = entry[2]
			healer.heal_shield_cap_fraction = entry[3]
			var sim := BattleSim.new()
			sim.setup([guard, healer], [_passive()], 311, [], [], [2, 3], [1])
			var target := sim.units[0]
			target.shield = entry[0]
			target.suppression_fraction = 0.25
			target.suppression_timer = 1.0
			if reverse:
				sim._queue_heal_protection(sim.units[1], target)
				sim._queue_self_shield(target)
			else:
				sim._queue_self_shield(target)
				sim._queue_heal_protection(sim.units[1], target)
			sim._apply_pending_protection()
			_near(target.shield, entry[4], "Mixed shield sources retain individual caps independent of queue order")
			_near(target.shield_timer, 3.0, "Mixed shield durations refresh to the longest duration")
			_near(target.suppression_timer, 0.0, "Canonical protection ordering preserves cleanse")
			_near(target.control_immunity_timer, 0.75, "Canonical protection ordering preserves immunity")
			_expect(sim._pending_protection.is_empty(), "Mixed protection queue drains completely")
			if reverse:
				_expect(_snapshot(sim) == reference, "Reversed protection queues produce identical state and events")
			else:
				reference = _snapshot(sim)


func _test_mixed_shields_in_combat() -> void:
	for side in [0, 1]:
		for reverse in [false, true]:
			var guard := _shield_guard()
			var healer := _shield_healer()
			var hand: Array[UnitDefinition] = []
			var levels: Array[int] = []
			hand.assign([healer, guard] if reverse else [guard, healer])
			levels.assign([3, 2] if reverse else [2, 3])
			var sim := BattleSim.new()
			if side == 0:
				sim.setup(hand, [_piercer()], 313, [], [], levels, [2])
			else:
				sim.setup([_piercer()], hand, 313, [], [], [2], levels)
			var target: SimUnit
			for unit in sim.units:
				if unit.def == guard:
					target = unit
					unit.pos = Vector2(10.0, 7.0)
				elif unit.def == healer:
					unit.pos = Vector2(8.0, 7.0)
				else:
					unit.pos = Vector2(14.0, 7.0)
			target.hp = 300.0
			target.shield = 90.0
			target.shield_timer = 1.0
			sim.tick()
			_near(target.shield, 134.0, "Mixed same-tick protection precedes shieldable damage on side %d reverse %s" % [side, reverse])
			_near(target.hp, 295.0, "Mixed same-tick protection preserves healing and bypass damage")
			_near(target.shield_timer, 3.0, "Both source durations apply before the combat tick resolves")
			_expect(sim._pending_protection.is_empty(), "Combat tick clears mixed protection queue")


func _snapshot(sim: BattleSim) -> Array:
	var state: Array = [sim.elapsed, sim._last_action_elapsed, sim.result, sim.rng.state,
		sim.events.duplicate(true), sim._fire_patches.duplicate(true), sim._pending_lunges.duplicate(true),
		sim._pending_protection.duplicate(true), sim._pending_statuses.duplicate(true)]
	for unit in sim.units:
		state.append([unit.id, unit.team, unit.level, unit.power_multiplier, unit.hp,
			unit.pos, unit.target_id, unit.threat_id, unit.attack_cooldown,
			unit.stagger_timer, unit.alive, unit.pending_damage, unit.pending_shield_bypass, unit.pending_heal,
			unit.attacks_fired, unit.shield, unit.shield_timer, unit.slow_fraction, unit.slow_timer,
			unit.suppression_fraction, unit.suppression_timer, unit.vulnerability_fraction,
			unit.vulnerability_timer, unit.control_immunity_timer])
	return state


func _test_seeded_replay() -> void:
	var hand_a: Array[UnitDefinition] = [UnitDatabase.ENFORCER, UnitDatabase.DEMOLITIONIST,
		UnitDatabase.FIELD_MEDIC, UnitDatabase.MARKSMAN]
	var hand_b: Array[UnitDefinition] = [UnitDatabase.TROOPER, UnitDatabase.ENFORCER,
		UnitDatabase.DEMOLITIONIST, UnitDatabase.FIELD_MEDIC]
	var power: Array[float] = [2.0, 1.5, 1.5, 1.0]
	var levels: Array[int] = [3, 2, 2, 1]
	for seed_value in [71, 79, 83]:
		var first := BattleSim.new()
		var second := BattleSim.new()
		first.setup(hand_a, hand_b, seed_value, power, power, levels, levels)
		second.setup(hand_a, hand_b, seed_value, power, power, levels, levels)
		var identical := true
		var ticks := 0
		while first.result == BattleSim.Result.IN_PROGRESS and ticks < 5402:
			first.tick()
			second.tick()
			ticks += 1
			if _snapshot(first) != _snapshot(second):
				identical = false
				break
		_expect(identical, "Seed %d reproduces every tick's state, RNG, hazards and events" % seed_value)
		_expect(first.result != BattleSim.Result.IN_PROGRESS,
			"Seed %d terminates within the simulation time limit" % seed_value)
