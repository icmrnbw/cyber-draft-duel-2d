extends SceneTree
## Ten-unit roster ability gates, targeting, refresh, expiry and seeded replay.
## All fixtures modify duplicated/in-memory resources, never player progress.

const EPSILON := 0.00001
var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	_test_shipped_resource_fields()
	_test_expanded_roster_resources()
	_test_bulwark_shield_and_suppression()
	_test_phaseblade_lunge_and_mark()
	_test_cryotek_tier_control()
	_test_arcrelay_chain_range_and_suppression()
	_test_nullbreaker_charge_and_mark()
	_test_nullbreaker_shield_boundaries()
	_test_nullbreaker_same_tick_protection()
	_test_nullbreaker_damage_modifiers()
	_test_nullbreaker_shipped_shield_matchups()
	_test_trooper_burst_and_suppression()
	_test_marksman_charge_and_mark()
	_test_medic_shield()
	_test_medic_cleanse_and_immunity()
	_test_demolitionist_slow()
	_test_strongest_status_refresh()
	_test_idle_portrait_resolver()
	_test_full_tier_replays()
	_test_expanded_shipped_replays()
	if _failures.is_empty():
		print("PASS: %d ten-unit roster ability checks" % _checks)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: %s" % failure)
		printerr("%d of %d ten-unit roster ability checks failed" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _near(actual: float, expected: float, message: String) -> void:
	_expect(absf(actual - expected) <= EPSILON,
		"%s (actual=%.9f expected=%.9f)" % [message, actual, expected])


func _fixture(source: UnitDefinition = null) -> UnitDefinition:
	var def: UnitDefinition = source.duplicate() if source != null else UnitDefinition.new()
	def.hp = 1000.0
	def.damage_per_hit = 10.0
	def.attacks_per_second = 60.0
	def.move_speed = 0.0
	def.preferred_range = 50.0
	def.retreat_range = 0.0
	def.self_defense_damage = 0.0
	return def


func _passive() -> UnitDefinition:
	var def := _fixture()
	def.preferred_range = 0.0
	return def


func _event(sim: BattleSim, type: String) -> Dictionary:
	for entry in sim.events:
		if entry["type"] == type:
			return entry
	return {}


func _ticks(sim: BattleSim, count: int) -> void:
	for _i in range(count):
		sim.tick()


func _test_shipped_resource_fields() -> void:
	_expect(UnitDatabase.TROOPER.special_attack_every == 4 and UnitDatabase.TROOPER.special_attack_hits == 3,
		"Shipped Trooper resource loads its burst configuration")
	_expect(UnitDatabase.TROOPER.suppression_min_level == 3 and UnitDatabase.TROOPER.suppression_fraction > 0.0,
		"Shipped Trooper resource loads its suppression configuration")
	_expect(UnitDatabase.MARKSMAN.special_attack_every == 3 and UnitDatabase.MARKSMAN.special_attack_damage_mult > 1.0,
		"Shipped Marksman resource loads its charged-shot configuration")
	_expect(UnitDatabase.MARKSMAN.mark_min_level == 3 and UnitDatabase.MARKSMAN.mark_damage_bonus > 0.0,
		"Shipped Marksman resource loads its mark configuration")
	_expect(UnitDatabase.FIELD_MEDIC.heal_shield_min_level == 2 and UnitDatabase.FIELD_MEDIC.heal_shield_amount > 0.0,
		"Shipped Medic resource loads its shield configuration")
	_expect(UnitDatabase.FIELD_MEDIC.shield_cleanse_min_level == 3 and UnitDatabase.FIELD_MEDIC.control_immunity_duration > 0.0,
		"Shipped Medic resource loads its cleanse configuration")
	_expect(UnitDatabase.DEMOLITIONIST.firepatch_slow_min_level == 3 and UnitDatabase.DEMOLITIONIST.firepatch_slow_fraction > 0.0,
		"Shipped Demolitionist resource loads its slow configuration")
	for def in [UnitDatabase.ENFORCER, UnitDatabase.TROOPER, UnitDatabase.MARKSMAN, UnitDatabase.FIELD_MEDIC, UnitDatabase.DEMOLITIONIST]:
		_expect(not def.ability_lv2_name.is_empty() and not def.ability_lv3_name.is_empty(),
			"Shipped %s resource loads tier ability metadata" % def.display_name)


func _test_expanded_roster_resources() -> void:
	var expected_names := ["Bulwark", "Phaseblade", "Cryotek", "ArcRelay", "Nullbreaker"]
	var expanded: Array[UnitDefinition] = [UnitDatabase.BULWARK, UnitDatabase.PHASEBLADE,
		UnitDatabase.CRYOTEK, UnitDatabase.ARCRELAY, UnitDatabase.NULLBREAKER]
	for i in range(expanded.size()):
		var def := expanded[i]
		_expect(def.display_name == expected_names[i], "Expanded resource %d has its authored name" % i)
		_expect(not def.idle_frames.is_empty() and def.idle_frames.size() == 4,
			"%s loads four Lv1 idle frames" % def.display_name)
		_expect(def.lv2_idle_frames.size() == 4 and def.lv3_idle_frames.size() == 4,
			"%s loads four idle frames for each tier" % def.display_name)
		_expect(not def.ability_lv2_name.is_empty() and not def.ability_lv3_name.is_empty(),
			"%s loads both tier ability names" % def.display_name)
	_expect(UnitDatabase.BULWARK.self_shield_min_level == 2 and UnitDatabase.BULWARK.self_shield_amount > 0.0,
		"Bulwark loads its self-shield gate")
	_expect(UnitDatabase.PHASEBLADE.special_lunge_distance > 0.0,
		"Phaseblade loads its lunge distance")
	_expect(UnitDatabase.CRYOTEK.on_hit_slow_min_level == 2 and UnitDatabase.CRYOTEK.on_hit_slow_fraction > 0.0,
		"Cryotek loads its hit slow")
	_expect(UnitDatabase.ARCRELAY.special_chain_targets == 2 and UnitDatabase.ARCRELAY.special_chain_damage_mult > 0.0,
		"ArcRelay loads deterministic chain parameters")
	_expect(UnitDatabase.NULLBREAKER.mark_min_level == 3 and UnitDatabase.NULLBREAKER.mark_damage_bonus > 0.0,
		"Nullbreaker loads its armor mark")
	_near(UnitDatabase.NULLBREAKER.special_shield_bypass_fraction, 0.8,
		"Nullbreaker loads its 80 percent shield bypass")
	_near(UnitDatabase.MARKSMAN.special_shield_bypass_fraction, 0.0,
		"Marksman charged rounds retain ordinary shield interaction")
	_expect(UnitDatabase.BULWARK.attack_frames.size() == 4 and UnitDatabase.BULWARK.lv2_attack_frames.size() == 4
		and UnitDatabase.BULWARK.lv3_attack_frames.size() == 4,
		"Bulwark loads reviewed attack frames for all tiers")
	_expect(UnitDatabase.BULWARK.walk_frames.size() == 4 and UnitDatabase.BULWARK.lv2_walk_frames.size() == 4
		and UnitDatabase.BULWARK.lv3_walk_frames.size() == 4,
		"Bulwark loads reviewed walk frames for all tiers")
	_expect(UnitDatabase.BULWARK.retreat_frames.size() == 4 and UnitDatabase.BULWARK.lv2_retreat_frames.size() == 4
		and UnitDatabase.BULWARK.lv3_retreat_frames.size() == 4,
		"Bulwark loads reviewed retreat frames for all tiers")

	_expect(UnitDatabase.PHASEBLADE.retreat_range < UnitDatabase.PHASEBLADE.preferred_range,
		"Phaseblade has a stable melee fighting range")


func _test_bulwark_shield_and_suppression() -> void:
	for level in [1, 2, 3]:
		for side in [0, 1]:
			var sim := BattleSim.new()
			var bulwark := _fixture(UnitDatabase.BULWARK)
			if side == 0:
				sim.setup([bulwark], [_fixture()], 211, [], [], [level], [1])
			else:
				sim.setup([_fixture()], [bulwark], 211, [], [], [1], [level])
			var actor := sim.units[side]
			var target := sim.units[1 - side]
			_ticks(sim, 3)
			_near(actor.shield, 0.0, "Bulwark waits for fourth attack to shield")
			sim.tick()
			_near(target.hp, 960.0 if level == 1 else 956.5, "Bulwark Lv%d special damage on side %d" % [level, side])
			_near(actor.hp, 960.0 if level == 1 else 970.0, "Bulwark shield absorbs same-tick hit on side %d" % side)
			_near(actor.shield, 0.0 if level == 1 else 14.0, "Bulwark self-shield gate and absorption")
			_near(actor.shield_timer, 0.0 if level == 1 else (2.5 if level == 2 else 3.5),
				"Bulwark Lv3 extends shield duration")
			_near(target.suppression_fraction, 0.15 if level == 3 else 0.0, "Bulwark suppression requires Lv3")
			_near(target.shield, 0.0, "Bulwark shields only itself")
	var cap_sim := BattleSim.new()
	cap_sim.setup([_fixture(UnitDatabase.BULWARK)], [_passive()], 213, [], [], [3], [1])
	_ticks(cap_sim, 52)
	_near(cap_sim.units[0].shield, 300.0, "Bulwark shield accumulation is capped at 30 percent max HP")
	_near(cap_sim.units[0].shield_timer, 3.5, "Bulwark refresh does not add duration")
	cap_sim.units[0].attack_cooldown = INF
	_ticks(cap_sim, 211)
	_near(cap_sim.units[0].shield, 0.0, "Bulwark unused shield expires")


func _test_phaseblade_lunge_and_mark() -> void:
	for level in [1, 2, 3]:
		var sim := BattleSim.new()
		sim.setup([_fixture(UnitDatabase.PHASEBLADE)], [_passive()], 217, [], [], [level], [1])
		sim.units[0].pos = Vector2(10.0, 7.0)
		sim.units[1].pos = Vector2(11.5, 7.0)
		_ticks(sim, 2)
		_near(sim.units[0].pos.x, 10.0, "Phaseblade waits for third attack to lunge")
		sim.tick()
		_near(sim.units[1].hp, 970.0 if level == 1 else 965.5, "Phaseblade Lv%d special damage" % level)
		_near(sim.units[0].pos.x, 10.0 if level == 1 else 10.5, "Phaseblade lunge stops at contact")
		_near(sim.units[1].vulnerability_fraction, 0.15 if level == 3 else 0.0, "Phaseblade mark requires Lv3")
		if level == 3:
			sim.tick()
			_near(sim.units[1].hp, 954.0, "Phaseblade mark amplifies the next hit")
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 109)
			_near(sim.units[1].vulnerability_fraction, 0.0, "Phaseblade mark expires")


func _test_cryotek_tier_control() -> void:
	for level in [1, 2, 3]:
		var sim := BattleSim.new()
		sim.setup([_fixture(UnitDatabase.CRYOTEK)], [_passive(), _passive(), _passive()], 223, [], [], [level], [1, 1, 1])
		sim.units[0].pos = Vector2(8.0, 7.0)
		sim.units[1].pos = Vector2(12.0, 7.0)
		sim.units[2].pos = Vector2(12.0, 8.3)
		sim.units[3].pos = Vector2(12.0, 10.0)
		_ticks(sim, 2)
		_near(sim.units[1].slow_fraction, 0.0 if level == 1 else 0.24, "Cryotek base slow requires Lv2")
		sim.tick()
		for id in [1, 2]:
			_near(sim.units[id].hp, 968.0 if level == 3 else 970.0, "Cryotek Lv3 burst adds splash damage")
			_near(sim.units[id].slow_fraction, 0.0 if level == 1 else (0.24 if level == 2 else 0.42),
				"Cryotek third-hit stronger slow requires Lv3")
			_near(sim.units[id].slow_timer, 0.0 if level == 1 else (1.25 if level == 2 else 1.6),
				"Cryotek tier slow duration")
		_near(sim.units[3].hp, 1000.0, "Cryotek splash excludes distant enemies")
		_near(sim.units[3].slow_fraction, 0.0, "Cryotek slow excludes distant enemies")
		_near(sim.units[0].slow_fraction, 0.0, "Cryotek never slows itself")
		if level == 3:
			sim.tick()
			_near(sim.units[1].slow_fraction, 0.42, "Ordinary hit does not weaken active strong cryo slow")
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 97)
			_near(sim.units[1].slow_fraction, 0.0, "Cryotek slow expires")


func _test_arcrelay_chain_range_and_suppression() -> void:
	for level in [1, 2, 3]:
		var sim := BattleSim.new()
		sim.setup([_fixture(UnitDatabase.ARCRELAY), _passive()],
			[_passive(), _passive(), _passive(), _passive(), _passive()], 227, [], [], [level, 1], [1, 1, 1, 1, 1])
		sim.units[0].pos = Vector2(8.0, 7.0)
		sim.units[1].pos = Vector2(13.0, 7.0) # Ally near impact, never a chain target.
		sim.units[2].pos = Vector2(12.0, 7.0)
		sim.units[3].pos = Vector2(12.0, 9.0)
		sim.units[4].pos = Vector2(12.0, 5.0) # Equal distance: lower id wins first.
		sim.units[5].pos = Vector2(15.0, 7.0) # In range but over target count.
		sim.units[6].pos = Vector2(18.0, 7.0) # Outside radius.
		_ticks(sim, 3)
		_near(sim.units[3].hp, 1000.0, "ArcRelay waits for fourth attack to chain")
		sim.tick()
		_near(sim.units[2].hp, 960.0 if level == 1 else 958.0, "ArcRelay primary special damage")
		for id in [3, 4]:
			_near(sim.units[id].hp, 1000.0 if level == 1 else 993.4, "ArcRelay reduced secondary damage")
		for id in [1, 5, 6]:
			_near(sim.units[id].hp, 1000.0, "ArcRelay excludes allies, overflow and out-of-range enemies")
		for id in [2, 3, 4]:
			_near(sim.units[id].suppression_fraction, 0.2 if level == 3 else 0.0, "ArcRelay suppression requires Lv3")
		if level >= 2:
			_expect(_event(sim, "chain").get("targets", []) == [3, 4], "ArcRelay chain sorts by distance then id")
		else:
			_expect(_event(sim, "chain").is_empty(), "ArcRelay Lv1 has no chain")
		if level == 3:
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 85)
			_near(sim.units[3].suppression_fraction, 0.0, "ArcRelay suppression expires")
	var ranged := BattleSim.new()
	ranged.setup([_fixture(UnitDatabase.ARCRELAY)], [_passive(), _passive()], 229, [], [], [2], [1, 1])
	ranged.units[0].pos = Vector2(8.0, 7.0)
	ranged.units[1].pos = Vector2(12.0, 7.0)
	ranged.units[2].pos = Vector2(16.0, 7.0)
	_ticks(ranged, 4)
	_near(ranged.units[2].hp, 1000.0, "ArcRelay cannot chain across an empty gap")
	_expect(_event(ranged, "chain").is_empty(), "No chain event is emitted without a legal secondary target")
	ranged.units[2].pos = Vector2(15.5, 7.0)
	_expect(ranged._find_chain_targets(ranged.units[0], ranged.units[1], 2).size() == 1,
		"Chain includes a secondary exactly on the configured radius")
	ranged.units[2].pos.x = 15.5001
	_expect(ranged._find_chain_targets(ranged.units[0], ranged.units[1], 2).is_empty(),
		"Chain excludes a secondary immediately outside the configured radius")
	ranged.units[2].pos.x = 14.0
	ranged.units[2].alive = false
	_expect(ranged._find_chain_targets(ranged.units[0], ranged.units[1], 2).is_empty(),
		"Chain excludes dead secondaries")


func _test_nullbreaker_charge_and_mark() -> void:
	for level in [1, 2, 3]:
		var sim := BattleSim.new()
		sim.setup([_fixture(UnitDatabase.NULLBREAKER)], [_passive()], 233, [], [], [level], [1])
		_ticks(sim, 2)
		_near(sim.units[1].hp, 980.0, "Nullbreaker charges for two ordinary shots")
		sim.units[1].shield = 12.0
		sim.units[1].shield_timer = 3.0
		sim.tick()
		_near(sim.units[1].hp, 980.0 if level == 1 else 966.0, "Nullbreaker bypass respects the Lv2 special gate")
		_near(sim.units[1].shield, 2.0 if level == 1 else 8.5, "Nullbreaker shield absorbs only the non-piercing portion")
		_near(sim.units[1].vulnerability_fraction, 0.25 if level == 3 else 0.0, "Nullbreaker mark requires Lv3")
		if level == 3:
			sim.tick()
			_near(sim.units[1].hp, 962.0, "Nullbreaker mark amplifies follow-up damage")
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 151)
			_near(sim.units[1].vulnerability_fraction, 0.0, "Nullbreaker mark expires")


func _test_nullbreaker_shield_boundaries() -> void:
	for level in [1, 2, 3]:
		var def := _fixture(UnitDatabase.NULLBREAKER)
		var ordinary := BattleSim.new()
		ordinary.setup([def], [_passive()], 251, [], [], [level], [1])
		ordinary.units[1].shield = 100.0
		ordinary.units[1].shield_timer = 3.0
		_ticks(ordinary, 2)
		_near(ordinary.units[1].hp, 1000.0, "Nullbreaker ordinary hits never bypass shields at Lv%d" % level)
		_near(ordinary.units[1].shield, 80.0, "Both ordinary hits consume their full shield damage")
		var plain: UnitDefinition = def.duplicate()
		plain.special_shield_bypass_fraction = 0.0
		var piercing := BattleSim.new()
		var reference := BattleSim.new()
		piercing.setup([def], [_passive()], 253, [], [], [level], [1])
		reference.setup([plain], [_passive()], 253, [], [], [level], [1])
		for _tick in range(6):
			piercing.tick()
			reference.tick()
			_expect(_snapshot(piercing) == _snapshot(reference),
				"Shield bypass changes no unshielded state or event at Lv%d" % level)
	for initial_shield in [0.0, 2.0]:
		var sim := BattleSim.new()
		sim.setup([_fixture(UnitDatabase.NULLBREAKER)], [_passive()], 257, [], [], [2], [1])
		sim.units[0].attacks_fired = 2
		sim.units[1].shield = initial_shield
		sim.units[1].shield_timer = 3.0
		sim.tick()
		_near(sim.units[1].hp, 1000.0 - 17.5 + initial_shield,
			"Depleted or insufficient shield never duplicates the piercing portion")
		_near(sim.units[1].shield, 0.0, "Insufficient shield is consumed completely")
		_near(sim.units[1].shield_timer, 0.0, "Depleted shield clears its timer")
	var marksman := BattleSim.new()
	marksman.setup([_fixture(UnitDatabase.MARKSMAN)], [_passive()], 263, [], [], [3], [1])
	marksman.units[0].attacks_fired = 2
	marksman.units[1].shield = 100.0
	marksman.units[1].shield_timer = 3.0
	marksman.tick()
	_near(marksman.units[1].hp, 1000.0, "Marksman charged shot cannot damage HP through a sufficient shield")
	_near(marksman.units[1].shield, 82.0, "Marksman deals its entire charged damage to shield")


func _test_nullbreaker_same_tick_protection() -> void:
	for side in [0, 1]:
		var sim := _medic_battle(2, _fixture(UnitDatabase.NULLBREAKER), side)
		var patient := sim.units[1 if side == 0 else 2]
		var attacker := sim.units[2 if side == 0 else 0]
		attacker.attacks_fired = 2
		sim.tick()
		_near(patient.hp, 491.0, "Piercing charged shot and same-tick heal resolve on side %d" % side)
		_near(patient.shield, 10.5, "Same-tick Medic shield absorbs the non-piercing portion on side %d" % side)
		_near(float(_event(sim, "shield_hit").get("amount", -1.0)), 3.5,
			"Shield impact reports absorbed damage rather than the full charged shot")
		_near(patient.vulnerability_fraction, 0.25, "Same-tick mark applies after charged damage calculation")
		var duel := BattleSim.new()
		if side == 0:
			duel.setup([_fixture(UnitDatabase.NULLBREAKER)], [_fixture(UnitDatabase.BULWARK)], 269, [], [], [2], [2])
		else:
			duel.setup([_fixture(UnitDatabase.BULWARK)], [_fixture(UnitDatabase.NULLBREAKER)], 269, [], [], [2], [2])
		duel.units[side].attacks_fired = 2
		duel.units[1 - side].attacks_fired = 3
		duel.tick()
		_near(duel.units[1 - side].hp, 986.0, "Bypass reaches HP through a same-tick self shield on side %d" % side)
		_near(duel.units[1 - side].shield, 20.5, "Bulwark retains the unused part of its same-tick shield")


func _test_nullbreaker_damage_modifiers() -> void:
	for power in [1.0, 2.0]:
		var sim := BattleSim.new()
		sim.setup([_fixture(UnitDatabase.NULLBREAKER)], [_passive()], 271, [], [], [3], [1])
		var attacker := sim.units[0]
		var target := sim.units[1]
		attacker.power_multiplier = power
		attacker.attacks_fired = 2
		attacker.suppression_fraction = 0.25
		attacker.suppression_timer = 3.0
		target.vulnerability_fraction = 0.2
		target.vulnerability_timer = 3.0
		target.shield = 100.0
		target.shield_timer = 3.0
		sim.tick()
		var total_damage: float = 17.5 * power * 0.75 * 1.2
		_near(target.hp, 1000.0 - total_damage * 0.8, "Power, suppression and active mark apply once to bypass")
		_near(target.shield, 100.0 - total_damage * 0.2, "Shieldable damage receives the same modifiers")
		_near(float(_event(sim, "ability").get("amount", -1.0)), total_damage,
			"Ability event retains total modified damage")
		_near(target.vulnerability_fraction, 0.25, "New stronger mark affects subsequent hits")
		_near(target.pending_shield_bypass, 0.0, "Damage resolution clears its bypass accumulator")


func _test_nullbreaker_shipped_shield_matchups() -> void:
	# Use the authored damage and actual tier multiplier: fixture-sized attacks
	# alone cannot establish whether the bypass matters against shipped shields.
	var power := RoundState.power_for_level(2)
	for shield_amount in [UnitDatabase.FIELD_MEDIC.heal_shield_amount, UnitDatabase.BULWARK.self_shield_amount]:
		var sim := BattleSim.new()
		sim.setup([UnitDatabase.NULLBREAKER], [_passive()], 277, [power], [], [2], [1])
		var attacker := sim.units[0]
		var target := sim.units[1]
		attacker.pos = Vector2(10.0, 7.0)
		target.pos = Vector2(16.0, 7.0)
		attacker.attacks_fired = 2
		var shield_before: float = shield_amount * power
		target.shield = shield_before
		target.shield_timer = 3.0
		var damage := UnitDatabase.NULLBREAKER.damage_per_hit * power * UnitDatabase.NULLBREAKER.special_attack_damage_mult
		sim.tick()
		_near(target.hp, 1000.0 - damage * 0.8, "Shipped charged shot pierces an equal-tier Medic/Bulwark shield")
		_near(target.shield, shield_before - damage * 0.2, "Shipped shield exceeds the shieldable portion")
		_expect(target.hp < 1000.0 - damage + shield_before,
			"Authored shield bypass causes earlier HP pressure than ordinary shield absorption")


func _test_trooper_burst_and_suppression() -> void:
	var trooper := _fixture(UnitDatabase.TROOPER)
	for level in [1, 2, 3]:
		var sim := BattleSim.new()
		sim.setup([trooper], [_fixture()], 101, [], [], [level], [1])
		_ticks(sim, 3)
		_expect(_event(sim, "ability").is_empty(), "Trooper Lv%d does not burst before fourth attack" % level)
		sim.tick()
		_near(sim.units[0].hp, 960.0, "Trooper Lv%d cannot suppress the opponent's already-decided attack" % level)
		_near(sim.units[1].hp, 960.0 if level == 1 else 952.0, "Trooper Lv%d fourth-attack damage" % level)
		_expect(sim.units[0].attacks_fired == 4, "Trooper burst rounds count as one completed attack")
		if level >= 2:
			var ability := _event(sim, "ability")
			_expect(ability.get("effect", "") == "burst" and ability.get("hits", 0) == 3,
				"Trooper burst event identifies three rounds")
		else:
			_expect(_event(sim, "ability").is_empty(), "Trooper Lv1 has no burst")
		_near(sim.units[1].suppression_fraction, 0.25 if level >= 3 else 0.0,
			"Trooper suppression respects its Lv3 gate")
		if level == 3:
			sim.tick()
			_near(sim.units[0].hp, 952.5, "Suppression reduces subsequent outgoing damage by 25 percent")
			sim.units[0].attack_cooldown = INF
			sim.units[1].attack_cooldown = INF
			_ticks(sim, 73)
			_near(sim.units[1].suppression_timer, 0.0, "Suppression expires")
			_near(sim.units[1].suppression_fraction, 0.0, "Expired suppression leaves no damage penalty")


func _test_marksman_charge_and_mark() -> void:
	var marksman := _fixture(UnitDatabase.MARKSMAN)
	for level in [1, 2, 3]:
		var sim := BattleSim.new()
		sim.setup([marksman], [_passive()], 103, [], [], [level], [1])
		_ticks(sim, 2)
		_expect(_event(sim, "ability").is_empty(), "Marksman charge waits for third attack")
		sim.tick()
		_near(sim.units[1].hp, 970.0 if level == 1 else 962.0, "Marksman Lv%d charged damage" % level)
		_near(sim.units[1].vulnerability_fraction, 0.2 if level >= 3 else 0.0,
			"Target Lock respects its Lv3 gate")
		if level >= 2:
			_expect(_event(sim, "ability").get("effect", "") == "charged", "Charged shot emits an ability event")
		if level == 3:
			sim.tick()
			_near(sim.units[1].hp, 950.0, "Marked target takes amplified follow-up damage")
			var hp_before := sim.units[1].hp
			sim._queue_damage(sim.units[1], 5.0)
			sim._apply_damage()
			_near(sim.units[1].hp, hp_before - 6.0, "Mark amplifies generic damage-over-time hits too")
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 121)
			_near(sim.units[1].vulnerability_timer, 0.0, "Target Lock expires")
			_near(sim.units[1].vulnerability_fraction, 0.0, "Expired mark leaves no vulnerability")


func _medic_battle(level: int, hostile: UnitDefinition = null, support_team: int = 0) -> BattleSim:
	var medic := _fixture(UnitDatabase.FIELD_MEDIC)
	medic.damage_per_hit = 5.0
	var enemy := hostile if hostile != null else _passive()
	var sim := BattleSim.new()
	if support_team == 0:
		sim.setup([medic, _passive()], [enemy], 107, [], [], [level, 1], [3])
		sim.units[0].pos = Vector2(8.0, 7.0)
		sim.units[1].pos = Vector2(11.0, 7.0)
		sim.units[2].pos = Vector2(12.5, 7.0)
		sim.units[1].hp = 500.0
	else:
		sim.setup([enemy], [medic, _passive()], 107, [], [], [3], [level, 1])
		sim.units[0].pos = Vector2(11.5, 7.0)
		sim.units[1].pos = Vector2(16.0, 7.0)
		sim.units[2].pos = Vector2(13.0, 7.0)
		sim.units[2].hp = 500.0
	return sim


func _test_medic_shield() -> void:
	for level in [1, 2]:
		var sim := _medic_battle(level)
		sim.tick()
		_near(sim.units[1].hp, 505.0, "Medic's healing remains functional at every tier")
		_near(sim.units[1].shield, 14.0 if level >= 2 else 0.0, "Aegis Dose respects Lv2 gate")
		_near(sim.units[0].shield, 0.0, "Heal shield does not target the Medic")
		_near(sim.units[2].shield, 0.0, "Heal shield never targets an enemy")
		if level == 2:
			_ticks(sim, 25)
			_near(sim.units[1].shield, 250.0, "Repeated healing shields cap at 25 percent of patient max HP")
			_near(sim.units[1].shield_timer, 3.0, "Shield refresh resets to duration instead of adding duration")
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 181)
			_near(sim.units[1].shield, 0.0, "Unspent shield expires completely")
			_near(sim.units[1].shield_timer, 0.0, "Shield timer finishes at zero")

	var attacker := _fixture()
	attacker.damage_per_hit = 30.0
	for side in [0, 1]:
		var sim := _medic_battle(2, attacker, side)
		var patient := sim.units[1 if side == 0 else 2]
		sim.tick()
		_near(patient.hp, 489.0, "Same-tick heal and shield absorb incoming damage on team %d" % side)
		_near(patient.shield, 0.0, "Damage consumes shield before HP")
		_near(float(_event(sim, "shield_hit").get("amount", -1.0)), 14.0, "Shield impact reports absorbed damage")

	var scaled := _medic_battle(2)
	scaled.units[0].power_multiplier = 1.5
	scaled.tick()
	_near(scaled.units[1].shield, 21.0, "Shield amount scales with the healer's power")


func _test_medic_cleanse_and_immunity() -> void:
	var controller := _fixture(UnitDatabase.TROOPER)
	controller.special_attack_every = 1
	controller.stagger_min_level = 1
	controller.stagger_chance = 1.0
	controller.stagger_duration = 0.4
	for level in [2, 3]:
		for side in [0, 1]:
			var sim := _medic_battle(level, controller, side)
			var patient := sim.units[1 if side == 0 else 2]
			patient.stagger_timer = 0.3
			patient.slow_fraction = 0.4
			patient.slow_timer = 1.0
			patient.suppression_fraction = 0.3
			patient.suppression_timer = 1.0
			patient.vulnerability_fraction = 0.2
			patient.vulnerability_timer = 1.0
			sim.tick()
			if level == 2:
				_expect(patient.stagger_timer > 0.0 and patient.slow_timer > 0.0 and patient.suppression_timer > 0.0,
					"Lv2 shield does not cleanse control on team %d" % side)
				_near(patient.control_immunity_timer, 0.0, "Control immunity respects Lv3 gate")
			else:
				_near(patient.stagger_timer, 0.0, "Trauma Reset clears existing and same-tick stagger on team %d" % side)
				_near(patient.slow_timer, 0.0, "Trauma Reset clears slow")
				_near(patient.suppression_timer, 0.0, "Trauma Reset clears existing and same-tick suppression")
				_near(patient.control_immunity_timer, 0.75, "Trauma Reset grants bounded control immunity")
				_expect(patient.vulnerability_timer > 0.0, "Control cleanse does not remove damage marks")
				_expect(not _event(sim, "cleanse").is_empty(), "Trauma Reset emits clear feedback")
				sim._queue_status("slow", 0, patient.id, 0.5, 1.0)
				sim._queue_status("mark", 0, patient.id, 0.25, 1.0)
				sim._apply_pending_statuses()
				_near(patient.slow_timer, 0.0, "Control immunity blocks newly applied slow")
				_near(patient.vulnerability_fraction, 0.25, "Control immunity does not block marks")
				for unit in sim.units:
					unit.attack_cooldown = INF
				_ticks(sim, 46)
				_near(patient.control_immunity_timer, 0.0, "Control immunity expires without extending itself")
				sim._queue_status("stagger", 0, patient.id, 1.0, 0.2)
				sim._apply_pending_statuses()
				_near(patient.stagger_timer, 0.2, "Control can be applied again after immunity expires")


func _test_demolitionist_slow() -> void:
	var demo := _fixture(UnitDatabase.DEMOLITIONIST)
	demo.attacks_per_second = 1.0
	var mobile := _passive()
	mobile.move_speed = 6.0
	for level in [2, 3]:
		var sim := BattleSim.new()
		sim.setup([demo], [mobile], 109, [], [], [level], [1])
		var before := sim.units[1].pos
		sim.tick()
		var target := sim.units[1]
		_near(target.slow_fraction, 0.3 if level == 3 else 0.0, "Scorched Ground respects Lv3 gate")
		_near(before.distance_to(target.pos), (4.2 if level == 3 else 6.0) * BattleSim.TICK_DELTA,
			"Ground slow reduces actual movement by its configured fraction")
		_near(sim.units[0].slow_fraction, 0.0, "Fire patch never slows its owner's team")
		if level == 3:
			sim._maybe_spawn_fire_patch(sim.units[0], target.pos)
			sim.tick()
			_near(target.slow_fraction, 0.3, "Overlapping ground slows do not add")
			_near(target.slow_timer, 0.35, "Ground slow refreshes without accumulating duration")
			target.pos = Vector2(23.0, 1.0)
			target.def.move_speed = 0.0
			sim.units[0].attack_cooldown = INF
			_ticks(sim, 22)
			_near(target.slow_timer, 0.0, "Ground slow ends after leaving its patch")
			_near(target.slow_fraction, 0.0, "Expired ground slow restores normal movement")


func _test_strongest_status_refresh() -> void:
	var sim := BattleSim.new()
	sim.setup([_passive()], [_passive()], 113)
	for effect in ["slow", "suppression", "mark"]:
		sim._queue_status(effect, 0, 1, 0.4, 2.0)
		sim._queue_status(effect, 0, 1, 0.2, 1.0)
	sim._apply_pending_statuses()
	var target := sim.units[1]
	_near(target.slow_fraction, 0.4, "Slow retains strongest magnitude")
	_near(target.suppression_fraction, 0.4, "Suppression retains strongest magnitude")
	_near(target.vulnerability_fraction, 0.4, "Mark retains strongest magnitude")
	_near(target.slow_timer, 2.0, "Slow retains longest duration")
	_near(target.suppression_timer, 2.0, "Suppression retains longest duration")
	_near(target.vulnerability_timer, 2.0, "Mark retains longest duration")


func _test_idle_portrait_resolver() -> void:
	var def := UnitDefinition.new()
	var idle := GradientTexture2D.new()
	var attack := GradientTexture2D.new()
	def.lv2_idle_frames = [idle]
	def.lv2_attack_frames = [attack]
	_expect(def.idle_sprite_for_level(2) == idle, "Portrait prefers actual idle art")
	_expect(def.idle_sprite_for_level(3) == idle, "Portrait preserves tier-aware idle fallback")
	def.lv2_idle_frames = []
	_expect(def.idle_sprite_for_level(2) == attack, "Legacy resources preserve attack-frame portrait fallback")


func _snapshot(sim: BattleSim) -> Array:
	var snapshot: Array = [sim.elapsed, sim.result, sim.rng.state,
		sim.events.duplicate(true), sim._fire_patches.duplicate(true),
		sim._pending_statuses.duplicate(true), sim._pending_protection.duplicate(true),
		sim._pending_lunges.duplicate(true)]
	for unit in sim.units:
		snapshot.append([unit.hp, unit.pos, unit.target_id, unit.threat_id, unit.alive,
			unit.attack_cooldown, unit.attacks_fired, unit.pending_damage, unit.pending_shield_bypass, unit.pending_heal,
			unit.stagger_timer, unit.shield, unit.shield_timer, unit.slow_fraction, unit.slow_timer,
			unit.suppression_fraction, unit.suppression_timer, unit.vulnerability_fraction,
			unit.vulnerability_timer, unit.control_immunity_timer])
	return snapshot


func _test_full_tier_replays() -> void:
	var hand_a: Array[UnitDefinition] = [UnitDatabase.TROOPER, UnitDatabase.MARKSMAN,
		UnitDatabase.FIELD_MEDIC, UnitDatabase.ENFORCER]
	var hand_b: Array[UnitDefinition] = [UnitDatabase.DEMOLITIONIST, UnitDatabase.FIELD_MEDIC,
		UnitDatabase.ENFORCER, UnitDatabase.TROOPER]
	var seen_events: Dictionary = {}
	for seed_value in [127, 131, 137]:
		var first := BattleSim.new()
		var second := BattleSim.new()
		first.setup(hand_a, hand_b, seed_value, [2.0, 2.0, 2.0, 2.0], [2.0, 2.0, 2.0, 2.0],
			[3, 3, 3, 3], [3, 3, 3, 3])
		second.setup(hand_a, hand_b, seed_value, [2.0, 2.0, 2.0, 2.0], [2.0, 2.0, 2.0, 2.0],
			[3, 3, 3, 3], [3, 3, 3, 3])
		var identical := true
		var ticks := 0
		while first.result == BattleSim.Result.IN_PROGRESS and ticks < 5402:
			first.tick()
			second.tick()
			for event in first.events:
				var kind: String = event.get("effect", event["type"]) if event["type"] == "ability" else event["type"]
				seen_events[kind] = int(seen_events.get(kind, 0)) + 1
			ticks += 1
			if _snapshot(first) != _snapshot(second):
				identical = false
				break
		_expect(identical, "Full-tier seed %d reproduces all per-tick state and events" % seed_value)
		_expect(first.result != BattleSim.Result.IN_PROGRESS, "Full-tier seed %d completes" % seed_value)
	for effect in ["burst", "charged", "suppression", "mark", "shield", "cleanse", "slow", "fire_patch_spawn", "stagger"]:
		_expect(int(seen_events.get(effect, 0)) > 0, "Unmodified shipped resources trigger %s in full-tier battles" % effect)
	print("Shipped-resource replay ability events: %s" % str(seen_events))


func _test_expanded_shipped_replays() -> void:
	# Unmodified shipped stats, animations and ability fields; only match tiers
	# and legal duplicate placements vary. This catches invalid .tres loading as
	# well as mechanics that passed artificial fast-attack fixtures but never fire.
	var hands: Array = [
		[UnitDatabase.BULWARK, UnitDatabase.PHASEBLADE, UnitDatabase.CRYOTEK, UnitDatabase.ARCRELAY],
		[UnitDatabase.NULLBREAKER, UnitDatabase.BULWARK, UnitDatabase.FIELD_MEDIC, UnitDatabase.TROOPER],
		[UnitDatabase.PHASEBLADE, UnitDatabase.ENFORCER, UnitDatabase.MARKSMAN, UnitDatabase.DEMOLITIONIST],
		[UnitDatabase.ARCRELAY, UnitDatabase.CRYOTEK, UnitDatabase.BULWARK, UnitDatabase.FIELD_MEDIC],
	]
	var seen: Dictionary = {}
	for level in [1, 2, 3]:
		for pairing in range(hands.size()):
			var hand_a: Array[UnitDefinition] = []
			var hand_b: Array[UnitDefinition] = []
			hand_a.assign(hands[pairing])
			hand_b.assign(hands[(pairing + 1) % hands.size()])
			var first := BattleSim.new()
			var second := BattleSim.new()
			var seed_value := 239 + pairing
			var levels: Array[int] = [level, level, level, level]
			first.setup(hand_a, hand_b, seed_value, [], [], levels, levels)
			second.setup(hand_a, hand_b, seed_value, [], [], levels, levels)
			var identical := true
			var ticks := 0
			while first.result == BattleSim.Result.IN_PROGRESS and ticks < 5402:
				first.tick()
				second.tick()
				for event in first.events:
					if event["type"] == "ability":
						var effect: String = event["effect"]
						seen[effect] = int(seen.get(effect, 0)) + 1
				if _snapshot(first) != _snapshot(second):
					identical = false
					break
				ticks += 1
			_expect(identical, "Expanded shipped Lv%d pairing %d replays exactly" % [level, pairing])
			_expect(first.result != BattleSim.Result.IN_PROGRESS,
				"Expanded shipped Lv%d pairing %d completes" % [level, pairing])
	for effect in ["aegis", "lunge", "cryo_burst", "chain", "pierce"]:
		_expect(int(seen.get(effect, 0)) > 0, "Unmodified new-unit resources trigger %s in real battles" % effect)
	print("Expanded shipped-resource replay abilities: %s" % str(seen))
