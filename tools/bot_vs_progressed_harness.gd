extends SceneTree
## Throwaway measurement: how does the bot (auto_grow_side only, current
## constants) fare against a fully-progressed human (every unit's tiers
## unlocked to Lv.3, always picks the single strongest available offer each
## growth slot) across many rounds? balance_harness.gd only measures
## bot-vs-bot (both auto-growing, no leveling) -- that's the right tool for
## unit-vs-unit balance, but says nothing about the actual asymmetry a real
## progressed player exploits: levelup access the bot structurally can't use.
##
## "Strongest offer" heuristic: double > levelup > add. power_for_level()
## makes a levelup a flat +50%/+33% per-unit multiplier (L1->2, L2->3), but a
## double gives a flat 2x on that group's TOTAL power and total effective HP
## every time, regardless of current level -- strictly bigger in raw terms.
## (An earlier version of this test scored levelup highest, which understated
## a good human player's performance -- see the 2026-09-06 tuning session.)
## Still greedy/imperfect (ignores tactical concentration-vs-spread effects
## real combat has beyond pure stat totals), but closer to "plays well."

const SEEDS := 10


func _hand_missing(roster: Array[UnitDefinition], skip_index: int) -> Array[UnitDefinition]:
	var hand: Array[UnitDefinition] = []
	for i in range(roster.size()):
		if i != skip_index:
			hand.append(roster[i])
	return hand


func _pick_best_offer(offers: Array) -> int:
	var best_i := 0
	var best_score := -1
	for i in range(offers.size()):
		var kind: String = offers[i]["kind"]
		var score := 0
		if kind == "double":
			score = 3
		elif kind == "levelup":
			score = 2
		else:
			score = 1
		if score > best_score:
			best_score = score
			best_i = i
	return best_i


## Side A = bot (auto_grow_side, current constants). Side B = fully-unlocked
## human playing greedily. Returns winner (0=bot, 1=human, -1=draw).
func _play_match(hand_bot: Array[UnitDefinition], hand_human: Array[UnitDefinition], seed_value: int) -> int:
	var rs := RoundState.new()
	rs.init(hand_bot, hand_human, seed_value)
	var max_level_by_path := {}
	for u in hand_human:
		max_level_by_path[u.resource_path] = RoundState.MAX_LEVEL

	var safety := 0
	# Test-local round cap (below RoundState.MAX_ROUNDS=10) -- a human who
	# always grabs "double" over "levelup" (now the correct greedy choice,
	# see above) can compound a group's count exponentially round over round,
	# and BattleSim's per-tick cost balloons with it. Real matches can hit
	# this too (worth a separate look at whether unbounded roster growth is
	# a real performance risk), but for THIS measurement, capping at round 5
	# keeps runtime sane while still capturing several rounds of real
	# divergence between the two growth strategies.
	while not rs.is_match_over() and safety < 60 and rs.round_number <= 5:
		safety += 1
		var sim := BattleSim.new()
		sim.setup(rs.roster_a, rs.roster_b, rs.current_seed(),
			rs.power_a, rs.power_b, rs.levels_a, rs.levels_b)
		sim.run_to_completion()
		rs.record_round_result(sim.result)
		if sim.result == BattleSim.Result.DRAW:
			continue
		if rs.is_match_over():
			break
		var bot_lost := rs.last_round_result == BattleSim.Result.TEAM_B
		var human_lost := rs.last_round_result == BattleSim.Result.TEAM_A

		# difficulty_scale=1.0 -- this test's human is already fully unlocked
		# (see max_level_by_path above), so this measures the bot's toughest
		# configuration against its toughest opponent.
		rs.auto_grow_side(0, bot_lost, 1.0)

		var slots := rs.additions_for(human_lost)
		for slot_i in range(slots):
			var offers := rs.roll_offers(1, slot_i, max_level_by_path)
			if offers.is_empty():
				continue
			var picked := _pick_best_offer(offers)
			rs.apply_offer(1, offers[picked])

		rs.advance_round_number()

	return rs.winner_team()


func _initialize() -> void:
	var roster := UnitDatabase.roster()
	var hands: Array = []
	var names: Array[String] = []
	for i in range(roster.size()):
		hands.append(_hand_missing(roster, i))
		names.append("no_%s" % roster[i].display_name.replace(" ", ""))

	print("=== Bot (auto_grow) vs fully-progressed human (all Lv.3, greedy picks) ===")
	print("current constants: BASE_GROWTH=%d COMEBACK_BONUS=%d DOUBLE_CHANCE=%.2f\n" % [
		RoundState.BASE_GROWTH, RoundState.COMEBACK_BONUS, RoundState.DOUBLE_CHANCE])

	var bot_wins := 0
	var human_wins := 0
	var draws := 0
	var total := 0

	for i in range(hands.size()):
		for j in range(hands.size()):
			for s in range(SEEDS):
				var winner := _play_match(hands[i], hands[j], 2000 + s * 7919 + i * 131 + j * 17)
				total += 1
				if winner == 0:
					bot_wins += 1
				elif winner == 1:
					human_wins += 1
				else:
					draws += 1
				if total % 25 == 0:
					print("  ...%d matches done" % total)

	print("total matches: %d" % total)
	print("bot win rate: %.1f%%" % (100.0 * float(bot_wins) / float(total)))
	print("human win rate: %.1f%%" % (100.0 * float(human_wins) / float(total)))
	print("draw rate: %.1f%%" % (100.0 * float(draws) / float(total)))
	quit()
