extends SceneTree
## Headless logic-only check for the ported RoundState+BattleSim loop, decoupled
## from match_controller.gd's async growth-pick UI so a hang can be isolated to
## either the ported sim logic or the visual/await layer.

func _initialize() -> void:
	# Real drafted hands are 4 DISTINCT types (draft_screen.gd enforces one of
	# each; unit_database.gd's bot hands match). The old version of this test
	# used 4x Trooper vs 3x Trooper, which is no longer a legal hand AND could
	# grow into an exactly-mirrored all-Trooper roster that draws forever
	# (Trooper-vs-Trooper combat has no RNG to break the tie) -- it hit the
	# safety cap harmlessly but told us nothing. Distinct hands exercise the
	# real matchup math instead.
	var roster := UnitDatabase.roster()
	var hand_a: Array[UnitDefinition] = [roster[5], roster[6], roster[7], roster[8]]
	var hand_b: Array[UnitDefinition] = [roster[0], roster[2], roster[4], roster[9]]
	var caps := {}
	for unit in roster:
		caps[unit.resource_path] = 3
	var promotions := 0

	var rs := RoundState.new()
	rs.init(hand_a, hand_b, 1)

	var safety := 0
	while not rs.is_match_over() and safety < 40:
		safety += 1
		var sim := BattleSim.new()
		rs.setup_sim(sim)
		var ticks := sim.run_to_completion()
		print("round=%d ticks=%d result=%d roster_a=%d roster_b=%d lives_a=%d lives_b=%d levels_a=%s levels_b=%s" % [
			rs.round_number, ticks, sim.result, rs.roster_a.size(), rs.roster_b.size(), rs.lives_a, rs.lives_b,
			str(rs.levels_a), str(rs.levels_b)])
		rs.record_round_result(sim.result)
		if sim.result == BattleSim.Result.IN_PROGRESS:
			printerr("FAIL: nonterminal battle")
			quit(1)
			return
		if sim.result == BattleSim.Result.DRAW and not rs.draw_round_resolved:
			print("  -> draw, replaying round %d" % rs.round_number)
			continue
		if rs.is_match_over():
			break
		var bot_side := 1
		var human_lost := rs.last_round_result == BattleSim.Result.TEAM_B or rs.draw_round_resolved
		rs.auto_grow_side(bot_side, not human_lost or rs.draw_round_resolved)
		var slots := rs.additions_for(human_lost)
		for slot_i in range(slots):
			var offers := rs.roll_offers(0, slot_i, caps)
			if offers.is_empty():
				continue
			var selected: Dictionary = offers[0]
			for offer in offers:
				if offer.kind == "levelup":
					selected = offer
					break
			promotions += int(selected.kind == "levelup")
			rs.apply_offer(0, selected)
		rs.advance_round_number()

	if not rs.is_match_over() or promotions == 0:
		printerr("FAIL: match did not terminate or unlocked growth was not exercised")
		quit(1)
		return
	print("MATCH OVER after %d rounds: lives_a=%d lives_b=%d winner=%d" % [
		rs.round_number, rs.lives_a, rs.lives_b, rs.winner_team()])
	print("PASS: new-unit match and %d legal tier promotions" % promotions)
	quit(0)
