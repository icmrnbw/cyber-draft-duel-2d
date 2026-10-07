extends Node
## Developer-only frame-cost probe for crowded rounds (excluded from export
## with tools/*). Starts a real match with N units per side, skips deployment,
## and prints frame-time stats once the battle is running. Desktop numbers are
## a relative proxy only; phone performance still needs a device.
## godot --resolution 720x1280 res://tools/crowd_perf.tscn -- --units=100

func _ready() -> void:
	var count := 50
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--units="):
			count = maxi(1, int(arg.trim_prefix("--units=")))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var roster := UnitDatabase.roster()
	var hand_a: Array[UnitDefinition] = []
	var hand_b: Array[UnitDefinition] = []
	for i in range(count):
		hand_a.append(roster[[0, 1, 2, 4][i % 4]])
		hand_b.append(roster[[5, 6, 7, 3][i % 4]])
	GameState.player_drafted_types = [roster[0], roster[1], roster[2], roster[4]]
	GameState.player_hand = hand_a
	GameState.bot_hand = hand_b
	GameState.match_seed = 4242
	var instance: Node = load("res://scenes/match.tscn").instantiate()
	get_tree().root.add_child.call_deferred(instance)
	for i in 90:
		await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			var shot := get_viewport().get_texture().get_image()
			shot.save_png(ProjectSettings.globalize_path("res://builds/" + arg.trim_prefix("--shot=").get_file()))
	var times: Array[float] = []
	var alive_start := _alive(instance)
	var last := Time.get_ticks_usec()
	for i in 300:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	var alive_end := _alive(instance)
	times.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= times.size()
	print("CROWD_PERF units_per_side=%d alive_start=%d alive_end=%d avg_ms=%.2f p50_ms=%.2f p95_ms=%.2f max_ms=%.2f" % [
		count, alive_start, alive_end, avg, times[times.size() / 2], times[int(times.size() * 0.95)], times[-1]])
	get_tree().quit()


func _alive(instance: Node) -> int:
	var sim = instance.get("_sim")
	if sim == null:
		return -1
	var n := 0
	for u in sim.units:
		if u.hp > 0.0:
			n += 1
	return n
