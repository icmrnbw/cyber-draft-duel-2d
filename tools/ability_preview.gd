extends "res://scripts/match_controller.gd"
## Runs actual deterministic combat through the production renderer, with no
## round rewards, unlock calls, scene navigation or profile writes.
var _qa_counts := {}
var _qa_captured := {}
var _qa_dense := false
var _qa_unit := ""
var _qa_peak_fx := 0
var _qa_require: PackedStringArray = []

func _ready() -> void:
	var ticks := 720
	var seed_value := 20261003
	for arg in OS.get_cmdline_user_args():
		if arg == "--dense":
			_qa_dense = true
		elif arg.begins_with("--ticks="):
			ticks = clampi(int(arg.substr(8)), 1, 1800)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		elif arg.begins_with("--unit="):
			_qa_unit = arg.substr(7)
		elif arg.begins_with("--require="):
			_qa_require = arg.substr(10).split(",", false)
	_build_background()
	var hand_a: Array[UnitDefinition] = []
	var hand_b: Array[UnitDefinition] = []
	var powers: Array[float] = []
	var levels: Array[int] = []
	var roster := UnitDatabase.roster()
	if not _qa_unit.is_empty():
		roster = roster.filter(func(unit: UnitDefinition) -> bool:
			return unit.resource_path.get_file().get_basename() == _qa_unit)
		if roster.size() != 1:
			push_error("Unknown ability preview unit: " + _qa_unit)
			get_tree().quit(1)
			return
	for copy_index in range(4 if _qa_dense else 1):
		for i in range(roster.size()):
			hand_a.append(roster[i])
			hand_b.append(roster[(i + 2) % roster.size()] if _qa_unit.is_empty() else UnitDatabase.BULWARK)
			powers.append(RoundState.power_for_level(3))
			levels.append(3)
	_sim = BattleSim.new()
	_sim.setup(hand_a, hand_b, seed_value, powers, powers, levels, levels)
	for unit in _sim.units:
		_views.append(_build_unit_view(unit))
	for tick_index in range(ticks):
		await get_tree().process_frame
		if _sim.result != BattleSim.Result.IN_PROGRESS:
			break
		_sim.tick()
		_consume_events()
		if is_instance_valid(_ability_fx_layer):
			_qa_peak_fx = maxi(_qa_peak_fx, _ability_fx_layer.get_child_count())
		for view in _views:
			_update_view(view)
		var capture_key := ""
		for event in _sim.events:
			var key: String = str(event.type)
			if key == "ability":
				key = str(event.get("effect", "ability"))
			_qa_counts[key] = int(_qa_counts.get(key, 0)) + 1
			if key in ["burst", "charged", "shield", "cleanse", "mark", "suppression", "stagger", "slow", "fire_patch_spawn", "aegis", "lunge", "cryo_burst", "chain", "pierce"] and not _qa_captured.has(key):
				capture_key = key
		for unit in _sim.units:
			if unit.alive and unit.def.berserk_min_level > 0 and unit.level >= unit.def.berserk_min_level and unit.hp_fraction() < 0.6 and not _qa_captured.has("berserk"):
				capture_key = "berserk"
		if not capture_key.is_empty():
			_qa_captured[capture_key] = true
			await _qa_capture(capture_key)
		if tick_index == 180:
			await _qa_capture("dense" if _qa_dense else "battle")
	await _qa_capture("final")
	var missing: Array[String] = []
	for required in _qa_require:
		if int(_qa_counts.get(required, 0)) == 0:
			missing.append(required)
	print("ABILITY_PREVIEW: ticks=", _sim.elapsed / BattleSim.TICK_DELTA, " result=", _sim.result, " events=", _qa_counts, " captures=", _qa_captured.keys(), " peak_ability_fx=", _qa_peak_fx, "/", MAX_ABILITY_FX, " missing=", missing)
	_free_views()
	await get_tree().process_frame
	var fx_cleared := not is_instance_valid(_ability_fx_layer) or _ability_fx_layer.get_child_count() == 0
	print("ABILITY_PREVIEW_CLEANUP: effects_cleared=", fx_cleared)
	get_tree().quit(0 if missing.is_empty() and _qa_peak_fx <= MAX_ABILITY_FX and fx_cleared else 1)

func _process(delta: float) -> void:
	_idle_phase += delta * 2.0
	_breathe_phase += delta

func _qa_capture(key: String) -> void:
	await RenderingServer.frame_post_draw
	var suffix := "dense-" if _qa_dense else "normal-"
	if not _qa_unit.is_empty():
		suffix += _qa_unit + "-"
	var path := preload("res://tools/output_safety.gd").checked_png_path("res://builds/ability-preview/" + suffix + key + ".png")
	if path.is_empty() or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		push_error("Rejected ability preview output")
		get_tree().quit(1)
		return
	if get_viewport().get_texture().get_image().save_png(path) != OK:
		push_error("Ability preview save failed")
		get_tree().quit(1)
		return
	print("ABILITY_CAPTURE: ", path)
