extends SceneTree
## Multi-round balance harness. The old (3D-project) harness only ever
## simulated ONE BattleSim round per matchup, which says nothing about a
## system whose whole shape is lives + roster growth + level-ups across many
## rounds -- a unit that wins round 1 but scales badly looks fine there and
## terrible in a real match.
##
## Since draft_screen.gd now enforces 4 DISTINCT types per hand and the roster
## has exactly 5 types, there are only C(5,4) = 5 legal hands, so the entire
## matchup space is a 5x5 matrix -- small enough to simulate exhaustively
## rather than sampling.
##
## Both sides use auto_grow_side() (the deterministic bot growth path) so this
## measures the UNITS, not a human's pick quality. Many seeds per matchup
## because a single seed is one anecdote.

const SEEDS_PER_MATCHUP := 40


func _hand_missing(roster: Array[UnitDefinition], skip_index: int) -> Array[UnitDefinition]:
	var hand: Array[UnitDefinition] = []
	for i in range(roster.size()):
		if i != skip_index:
			hand.append(roster[i])
	return hand


## One full multi-round match, both sides auto-growing. Returns the winner
## (0 = A, 1 = B, -1 = draw).
func _play_match(hand_a: Array[UnitDefinition], hand_b: Array[UnitDefinition], seed_value: int) -> int:
	var rs := RoundState.new()
	rs.init(hand_a, hand_b, seed_value)

	var safety := 0
	while not rs.is_match_over() and safety < 60:
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
		var a_lost := rs.last_round_result == BattleSim.Result.TEAM_B
		var b_lost := rs.last_round_result == BattleSim.Result.TEAM_A
		rs.auto_grow_side(0, a_lost)
		rs.auto_grow_side(1, b_lost)
		rs.advance_round_number()

	return rs.winner_team()


func _initialize() -> void:
	var roster := UnitDatabase.roster()
	var hand_names: Array[String] = []
	var hands: Array = []
	for i in range(roster.size()):
		hands.append(_hand_missing(roster, i))
		hand_names.append("no_%s" % roster[i].display_name.replace(" ", ""))

	print("=== Multi-round balance: %d hands, %d seeds each ===" % [hands.size(), SEEDS_PER_MATCHUP])
	print("(each hand is the full roster MINUS one type -- 4 distinct units, matching real draft rules)\n")

	var wins := {}
	var plays := {}
	for name in hand_names:
		wins[name] = 0
		plays[name] = 0

	var draws := 0
	var side_a_wins := 0
	var decisive := 0

	for i in range(hands.size()):
		for j in range(hands.size()):
			if i == j:
				continue  # mirror matchups are noise, both sides identical
			for s in range(SEEDS_PER_MATCHUP):
				var winner := _play_match(hands[i], hands[j], 1000 + s * 7919)
				plays[hand_names[i]] += 1
				plays[hand_names[j]] += 1
				if winner == 0:
					wins[hand_names[i]] += 1
					side_a_wins += 1
					decisive += 1
				elif winner == 1:
					wins[hand_names[j]] += 1
					decisive += 1
				else:
					draws += 1

	print("--- Per-hand win rate (50%% = perfectly balanced) ---")
	var rates: Array = []
	for name in hand_names:
		var rate := 100.0 * float(wins[name]) / maxf(float(plays[name]), 1.0)
		rates.append({"name": name, "rate": rate, "plays": plays[name]})
	rates.sort_custom(func(a, b): return a["rate"] > b["rate"])
	for r in rates:
		print("  %-22s %5.1f%%  (%d matches)" % [r["name"], r["rate"], r["plays"]])

	var spread: float = rates[0]["rate"] - rates[rates.size() - 1]["rate"]
	print("\n  spread (best - worst): %.1f percentage points" % spread)

	var total := decisive + draws
	print("\n--- Sanity checks ---")
	print("  total matches simulated: %d" % total)
	print("  draws: %d (%.1f%%)" % [draws, 100.0 * float(draws) / maxf(float(total), 1.0)])
	print("  side-A win share of decisive matches: %.1f%% (should be ~50%%, not a spawn-side bias)" % [
		100.0 * float(side_a_wins) / maxf(float(decisive), 1.0)])
	quit()
