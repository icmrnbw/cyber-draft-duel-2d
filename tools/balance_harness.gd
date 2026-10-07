extends SceneTree
## Deterministic balance measurements. Uses only in-memory RoundState/BattleSim.
## -- --report=res://builds/<fresh-name>.json [--suite=all|duels|squads|rounds]
## Reports refuse overwrites. Outcomes are samples, not proof of universal balance.

const DEFAULT_SEEDS: Array[int] = [1009, 8929, 16849]
## --seeds=N extends the panels to N deterministic seeds (first three are the
## historical ones) for larger samples; dense/slot panels use a third of them.
var SEEDS: Array[int] = DEFAULT_SEEDS.duplicate()
const MAX_MATCH_ATTEMPTS := 40
var _failures: Array[String] = []
var _battle_count := 0
var _match_count := 0
var _rows: Array = []
var _report_path := ""
var _suite := "all"
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			_report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--seeds="):
			var count := maxi(1, int(arg.trim_prefix("--seeds=")))
			SEEDS.clear()
			for i in range(count):
				SEEDS.append(DEFAULT_SEEDS[i] if i < DEFAULT_SEEDS.size() else 1009 + 7920 * i)
		elif arg.begins_with("--suite="):
			_suite = arg.trim_prefix("--suite=")
	if _report_path.is_empty() or not _report_path.begins_with("res://builds/") or ".." in _report_path or FileAccess.file_exists(_report_path):
		printerr("Report must name a NEW file directly under res://builds/; existing reports are preserved.")
		quit(2)
		return
	if _suite not in ["all", "duels", "squads", "rounds"]:
		printerr("Unknown suite: " + _suite)
		quit(2)
		return
	print("BALANCE START suite=%s seeds=%s" % [_suite, str(SEEDS)])
	if _suite in ["all", "duels"]:
		_run_duels()
	if _suite in ["all", "squads"]:
		_run_archetypes(1)
		_run_archetypes(3)
		_run_controlled_slots()
	if _suite in ["all", "rounds"]:
		_run_matches()
	_validate_coverage()
	var report := {"version": 1, "suite": _suite, "seeds": SEEDS,
		"battles": _battle_count, "matches": _match_count,
		"elapsed_seconds": float(Time.get_ticks_msec() - _started) / 1000.0,
		"rows": _rows, "failures": _failures, "stats": _resource_stats()}
	var file := FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write report: %s" % _report_path)
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BALANCE END battles=%d matches=%d seconds=%.2f failures=%d report=%s" % [
		_battle_count, _match_count, report["elapsed_seconds"], _failures.size(), _report_path])
	for failure in _failures:
		printerr("FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)


func _validate_coverage() -> void:
	# Godot can abort a nested function after a script error yet continue the
	# caller. Require every panel row before allowing a successful report.
	var units := UnitDatabase.roster().size()
	var archetypes := UnitDatabase.archetype_hands().size()
	var expected := {}
	if _suite in ["all", "duels"]:
		expected["duels"] = units * (units - 1) / 2 * 3
	if _suite in ["all", "squads"]:
		expected["squad4"] = archetypes * (archetypes - 1) / 2 * 3
		expected["dense12"] = expected["squad4"]
		expected["slot0"] = (units - 3) * 3 * 4
		expected["slot1"] = expected["slot0"]
	if _suite in ["all", "rounds"]:
		expected["fresh_match"] = archetypes
		expected["unlocked_match"] = archetypes
	for panel in expected:
		var actual := 0
		for row in _rows:
			actual += int(row["suite"] == panel)
		if actual != int(expected[panel]):
			_failures.append("Incomplete %s panel: expected %d rows, found %d" % [panel, expected[panel], actual])


func _resource_stats() -> Array:
	var out: Array = []
	for unit in UnitDatabase.roster():
		out.append({"unit": unit.display_name, "hp": unit.hp, "damage": unit.damage_per_hit,
			"aps": unit.attacks_per_second, "speed": unit.move_speed, "range": unit.preferred_range,
			"retreat": unit.retreat_range, "splash": unit.splash_radius})
	return out


func _typed(hand: Array) -> Array[UnitDefinition]:
	var out: Array[UnitDefinition] = []
	out.assign(hand)
	return out


func _battle(a: Array[UnitDefinition], b: Array[UnitDefinition], level: int, seed_value: int) -> Dictionary:
	var levels_a: Array[int] = []
	var levels_b: Array[int] = []
	var power_a: Array[float] = []
	var power_b: Array[float] = []
	for _unit in a:
		levels_a.append(level)
		power_a.append(RoundState.power_for_level(level))
	for _unit in b:
		levels_b.append(level)
		power_b.append(RoundState.power_for_level(level))
	var sim := BattleSim.new()
	sim.setup(a, b, seed_value, power_a, power_b, levels_a, levels_b)
	var ticks := sim.run_to_completion()
	_battle_count += 1
	if sim.result == BattleSim.Result.IN_PROGRESS:
		_failures.append("Nonterminal battle seed %d" % seed_value)
	return {"result": sim.result, "seconds": sim.elapsed, "ticks": ticks,
		"timeout": sim.elapsed >= BattleSim.MATCH_TIMEOUT,
		"hp_a": sim.total_hp(0), "hp_b": sim.total_hp(1)}


func _pair(suite: String, label_a: String, label_b: String, a: Array[UnitDefinition],
		b: Array[UnitDefinition], level: int, seeds: Array[int]) -> void:
	var row := {"suite": suite, "level": level, "a": label_a, "b": label_b,
		"a_wins": 0, "b_wins": 0, "draws": 0, "side_a_wins": 0,
		"plays": 0, "timeouts": 0, "seconds": 0.0}
	for seed_value in seeds:
		for reverse in [false, true]:
			var outcome := _battle(b if reverse else a, a if reverse else b, level, seed_value)
			row["plays"] += 1
			row["seconds"] += outcome["seconds"]
			row["timeouts"] += int(outcome["timeout"])
			if outcome["result"] == BattleSim.Result.DRAW:
				row["draws"] += 1
			elif outcome["result"] == BattleSim.Result.TEAM_A:
				row["side_a_wins"] += 1
				row["b_wins" if reverse else "a_wins"] += 1
			elif outcome["result"] == BattleSim.Result.TEAM_B:
				row["a_wins" if reverse else "b_wins"] += 1
	_rows.append(row)


func _run_duels() -> void:
	var roster := UnitDatabase.roster()
	for level in [1, 2, 3]:
		for i in range(roster.size()):
			for j in range(i + 1, roster.size()):
				_pair("duels", roster[i].display_name, roster[j].display_name,
					[roster[i]], [roster[j]], level, SEEDS)
		print("duels Lv%d complete; battles=%d" % [level, _battle_count])


func _dense(hand: Array[UnitDefinition], copies: int) -> Array[UnitDefinition]:
	var out: Array[UnitDefinition] = []
	for unit in hand:
		for _i in range(copies):
			out.append(unit)
	return out


func _run_archetypes(copies: int) -> void:
	var archetypes := UnitDatabase.archetype_hands()
	var names: Array = archetypes.keys()
	var seeds: Array[int] = []
	seeds.assign(SEEDS if copies == 1 else SEEDS.slice(0, maxi(1, SEEDS.size() / 3)))
	for level in [1, 2, 3]:
		for i in range(names.size()):
			for j in range(i + 1, names.size()):
				_pair("squad4" if copies == 1 else "dense12", names[i], names[j],
					_dense(_typed(archetypes[names[i]]), copies), _dense(_typed(archetypes[names[j]]), copies), level, seeds)
		print("archetypes copies=%d Lv%d complete; battles=%d" % [copies, level, _battle_count])


func _run_controlled_slots() -> void:
	var cores: Array = [
		[UnitDatabase.ENFORCER, UnitDatabase.TROOPER, UnitDatabase.FIELD_MEDIC],
		[UnitDatabase.CRYOTEK, UnitDatabase.ARCRELAY, UnitDatabase.NULLBREAKER],
	]
	var bench := UnitDatabase.archetype_hands()
	for panel in range(cores.size()):
		for unit in UnitDatabase.roster():
			if unit in cores[panel]:
				continue
			var hand := _typed(cores[panel])
			hand.append(unit)
			for level in [1, 2, 3]:
				for opponent in ["balanced", "control", "mobility", "anti_armor"]:
					_pair("slot%d" % panel, unit.display_name, opponent, hand, _typed(bench[opponent]), level, SEEDS.slice(0, maxi(1, SEEDS.size() / 3)))
		print("controlled slot panel=%d complete; battles=%d" % [panel, _battle_count])


func _pick_offer(offers: Array, unlocked: bool) -> Dictionary:
	# Deliberately prioritise legal level-ups for ability coverage, then double,
	# then add. This is an explicit test policy, not an optimal-human claim.
	for kind in (["levelup", "double", "add"] if unlocked else ["double", "add"]):
		for offer in offers:
			if offer["kind"] == kind:
				return offer
	return {}


func _play_match(a: Array[UnitDefinition], b: Array[UnitDefinition], seed_value: int,
		unlocked: bool, human_side: int) -> Dictionary:
	var rs := RoundState.new()
	rs.init(a, b, seed_value)
	var caps: Dictionary = {}
	if unlocked:
		for unit in UnitDatabase.roster():
			caps[unit.resource_path] = 3
	var attempts := 0
	var promotions := 0
	var max_roster := 4
	while not rs.is_match_over() and attempts < MAX_MATCH_ATTEMPTS:
		attempts += 1
		var sim := BattleSim.new()
		rs.setup_sim(sim)
		sim.run_to_completion()
		_battle_count += 1
		if sim.result == BattleSim.Result.IN_PROGRESS:
			_failures.append("Nonterminal round seed %d" % seed_value)
			break
		rs.record_round_result(sim.result)
		if rs.is_match_over():
			break
		if sim.result == BattleSim.Result.DRAW and not rs.draw_round_resolved:
			continue
		var human_lost := rs.draw_round_resolved or sim.result == (BattleSim.Result.TEAM_B if human_side == 0 else BattleSim.Result.TEAM_A)
		var bot_lost := rs.draw_round_resolved or not human_lost
		rs.auto_grow_side(1 - human_side, bot_lost, 1.0 if unlocked else 0.0)
		for slot in range(rs.additions_for(human_lost)):
			var offer := _pick_offer(rs.roll_offers(human_side, slot, caps), unlocked)
			if offer.is_empty():
				_failures.append("Empty growth offer seed %d" % seed_value)
				continue
			promotions += int(offer["kind"] == "levelup")
			rs.apply_offer(human_side, offer)
		max_roster = maxi(max_roster, maxi(rs.roster_a.size(), rs.roster_b.size()))
		rs.advance_round_number()
	_match_count += 1
	if not rs.is_match_over():
		_failures.append("Match seed %d exhausted %d attempts without terminal state" % [seed_value, attempts])
	return {"winner": rs.winner_team() if rs.is_match_over() else -2,
		"rounds": attempts, "promotions": promotions, "max_roster": max_roster}


func _run_matches() -> void:
	var archetypes := UnitDatabase.archetype_hands()
	var names: Array = archetypes.keys()
	for unlocked in [false, true]:
		for i in range(names.size()):
			var j := (i + 3) % names.size()
			var row := {"suite": "unlocked_match" if unlocked else "fresh_match", "a": names[i], "b": names[j],
				"plays": 0, "human_wins": 0, "bot_wins": 0, "draws": 0, "rounds": 0, "promotions": 0, "max_roster": 0}
			for seed_value in SEEDS:
				for human_side in [0, 1]:
					var a := _typed(archetypes[names[i] if human_side == 0 else names[j]])
					var b := _typed(archetypes[names[j] if human_side == 0 else names[i]])
					var result := _play_match(a, b, seed_value + i * 101, unlocked, human_side)
					row["plays"] += 1
					row["rounds"] += result["rounds"]
					row["promotions"] += result["promotions"]
					row["max_roster"] = maxi(row["max_roster"], result["max_roster"])
					if result["winner"] == human_side:
						row["human_wins"] += 1
					elif result["winner"] == 1 - human_side:
						row["bot_wins"] += 1
					else:
						row["draws"] += 1
			_rows.append(row)
			print("matches %s %s complete; matches=%d battles=%d" % ["unlocked" if unlocked else "fresh", names[i], _match_count, _battle_count])
