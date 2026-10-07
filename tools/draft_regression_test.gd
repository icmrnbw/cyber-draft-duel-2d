extends SceneTree
## Seeded draft composition and legal-hand enumeration. No profile/autoloads.
func _initialize() -> void:
	var failures: Array[String] = []
	var roster := UnitDatabase.roster()
	if roster.size() != 10:
		failures.append("Expected ten registered draftable units, got %d" % roster.size())
	var expected := 1
	for i in range(UnitDatabase.HAND_SIZE):
		expected = expected * (roster.size() - i) / (i + 1)
	var hands := UnitDatabase.all_distinct_hands()
	if hands.size() != expected:
		failures.append("Incorrect combination count: %d != %d" % [hands.size(), expected])
	var distinct := {}
	for hand in hands:
		if not UnitDatabase.valid_draft(hand):
			failures.append("Enumeration produced an invalid hand")
		var ids: Array[String] = []
		for unit in hand:
			ids.append(unit.resource_path)
		ids.sort()
		distinct["|".join(ids)] = true
	if distinct.size() != expected:
		failures.append("Enumeration has duplicate hands")
	if UnitDatabase.valid_draft([roster[0], roster[0], roster[1], roster[2]]):
		failures.append("Duplicate types were accepted")
	var seen := {}
	for seed_value in range(512):
		var a := RandomNumberGenerator.new()
		var b := RandomNumberGenerator.new()
		a.seed = seed_value
		b.seed = seed_value
		var left := UnitDatabase.random_bot_hand(a)
		var right := UnitDatabase.random_bot_hand(b)
		if left != right or a.state != b.state:
			failures.append("Same seed differs at %d" % seed_value)
		if not UnitDatabase.valid_draft(left):
			failures.append("Bot generated invalid hand at %d" % seed_value)
		for unit in left:
			seen[unit] = true
	if seen.size() != roster.size():
		failures.append("Some registered units never appear in seeded bot samples")
	for archetype_name in UnitDatabase.archetype_hands():
		if not UnitDatabase.valid_draft(UnitDatabase.archetype_hands()[archetype_name]):
			failures.append("Named archetype is not a legal draft: %s" % archetype_name)
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("PASS: %d legal four-of-ten hands; 512 deterministic bot samples; all %d units represented" % [hands.size(), roster.size()])
	quit()
