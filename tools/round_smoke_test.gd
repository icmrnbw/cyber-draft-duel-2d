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
	var hand_a: Array[UnitDefinition] = [roster[0], roster[1], roster[2], roster[3]]
	var hand_b: Array[UnitDefinition] = [roster[1], roster[2], roster[3], roster[4]]

	var rs := RoundState.new()
	rs.init(hand_a, hand_b, 1)

	var safety := 0
	while not rs.is_match_over() and safety < 40:
		safety += 1
		var sim := BattleSim.new()
		sim.setup(rs.roster_a, rs.roster_b, rs.current_seed(), rs.power_a, rs.power_b, rs.levels_a, rs.levels_b)
		var ticks := sim.run_to_completion()
		print("round=%d ticks=%d result=%d roster_a=%d roster_b=%d lives_a=%d lives_b=%d levels_a=%s levels_b=%s" % [
			rs.round_number, ticks, sim.result, rs.roster_a.size(), rs.roster_b.size(), rs.lives_a, rs.lives_b,
			str(rs.levels_a), str(rs.levels_b)])
		rs.record_round_result(sim.result)
		if sim.result == BattleSim.Result.DRAW:
			print("  -> draw, replaying round %d" % rs.round_number)
			continue
		if rs.is_match_over():
			break
		var bot_side := 1
		var human_lost := rs.last_round_result == BattleSim.Result.TEAM_B
		rs.auto_grow_side(bot_side, not human_lost)
		var slots := rs.additions_for(human_lost)
		for slot_i in range(slots):
			var offers := rs.roll_offers(0, slot_i)
			if offers.is_empty():
				continue
			rs.apply_offer(0, offers[0])
		rs.advance_round_number()

	print("MATCH OVER after %d rounds: lives_a=%d lives_b=%d winner=%d" % [
		rs.round_number, rs.lives_a, rs.lives_b, rs.winner_team()])
	quit()
