extends Node2D
## One-off visual QA tool (throwaway pattern established this project): loads
## a target scene headed (needs a real window, not --headless, for viewport
## capture) and dumps a PNG so screenshots can be compared directly against
## reference mockups without needing a phone/emulator.
## Usage: Godot --resolution 720x1280 --quit-after N res://tools/screenshot_tool.tscn -- --scene=res://scenes/main_menu.tscn --out=C:/path/out.png

func _ready() -> void:
	var scene_path := "res://scenes/main_menu.tscn"
	var out_path := "user://screenshot.png"
	var extra_wait := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.substr(8)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
		elif arg.begins_with("--wait="):
			extra_wait = int(arg.substr(7))

	if scene_path == "res://scenes/unit_detail_screen.tscn" and GameState.detail_unit_path == "":
		GameState.detail_unit_path = UnitDatabase.roster()[2].resource_path

	if scene_path == "res://scenes/match.tscn":
		# Set the fields GameState.start_match() would set WITHOUT calling it --
		# it calls change_scene_to_file() itself, which frees this very node
		# (the running main scene) out from under the still-executing _ready(),
		# killing get_tree() on the next await. Loading match.tscn ourselves
		# below (same as every other scene here) avoids that entirely.
		# Only sets player_drafted_types if a prior step in this same run
		# (e.g. --deploy_squad_test below) hasn't already set it, so that
		# simulated deployment's exact composition survives through to the
		# actual battle instead of being clobbered by the default here.
		# player_hand is deliberately left EMPTY by default (2026-09-11) --
		# that's the real flow every actual match now goes through
		# (_resolve_initial_deployment()'s in-match "choose 1 of 3" cards),
		# not a missing-state fallback anymore. Use --deploy_squad_test or
		# --auto_deploy to exercise/bypass that instead of hitting the
		# unattended-cards hang this tool would otherwise sit in forever.
		if GameState.player_drafted_types.is_empty():
			GameState.player_drafted_types = UnitDatabase.roster().slice(0, 4)
		var setup_rng := RandomNumberGenerator.new()
		setup_rng.randomize()
		GameState.match_seed = setup_rng.randi()
		var bot_rng := RandomNumberGenerator.new()
		bot_rng.seed = GameState.match_seed
		GameState.bot_hand = UnitDatabase.random_bot_hand(bot_rng)

	if OS.get_cmdline_user_args().has("--deploy_squad_test"):
		var roster := UnitDatabase.roster()
		GameState.player_drafted_types = [roster[0], roster[1], roster[2], roster[3]]
		GameState.player_hand = [roster[0], roster[0], roster[1], roster[1]]  # 2x + 2x

	var scene: PackedScene = load(scene_path)
	var instance: Node = scene.instantiate()
	get_tree().root.add_child.call_deferred(instance)
	await get_tree().process_frame
	await get_tree().process_frame

	if scene_path == "res://scenes/match.tscn" and OS.get_cmdline_user_args().has("--auto_deploy"):
		# Drives _resolve_initial_deployment()'s 4 "choose 1 of 3" cards by
		# emitting the same growth_offer_picked signal a real card tap
		# would -- always index 0, so this also doubles as a check that
		# repeatedly picking the same slot works (going all-in on one type
		# is an explicit design goal, not an edge case). Without this an
		# unattended run would just hang forever awaiting a pick that never
		# comes.
		for i in 4:
			for f in 8:
				await get_tree().process_frame
			instance.growth_offer_picked.emit(0)
		for f in 4:
			await get_tree().process_frame
		var roster_names := []
		for u in instance._round_state.roster_a:
			roster_names.append(u.display_name)
		print("AUTO_DEPLOY: final roster_a=", roster_names,
			" saved_for_rematch=", GameState.player_hand.size() == instance._round_state.roster_a.size())

	# Let extra frames pass for match.tscn so the sim/units settle into a
	# representative mid-setup frame before capture.
	var settle_frames := (40 if scene_path == "res://scenes/match.tscn" else 10) + extra_wait
	for i in settle_frames:
		await get_tree().process_frame

	if scene_path == "res://scenes/match.tscn" and OS.get_cmdline_user_args().has("--deploy_squad_test"):
		# Confirms the deployed multiset actually reached BattleSim as
		# roster_a (what's on the field) while type_pool_a (what "add"
		# growth offers can bring in later) still holds all 4 drafted
		# types, not just the 2 that got deployed.
		var rs = instance._round_state
		var roster_names := []
		for u in rs.roster_a:
			roster_names.append(u.display_name)
		var pool_names := []
		for u in rs.type_pool_a:
			pool_names.append(u.display_name)
		print("DEPLOY_SQUAD_TEST: roster_a=", roster_names, " type_pool_a=", pool_names)

	if OS.get_cmdline_user_args().has("--firepatch"):
		# Direct visual-only preview of shaders/fire_puddle.gdshader -- the
		# sim-side DoT logic itself is verified separately (a headless
		# _test_fire_patch.gd A/B run, deleted after use per convention),
		# this just checks the shader actually looks like fire in-engine.
		instance._spawn_fire_puddle(Vector2(360, 640), 90.0, 3.0)
		for i in 20:
			await get_tree().process_frame

	if OS.get_cmdline_user_args().has("--growth"):
		var roster := UnitDatabase.roster()
		var offers := [
			{"unit_def": roster[0], "kind": "double", "level": 1, "count": 8},
			{"unit_def": roster[1], "kind": "levelup", "level": 1, "count": 4},
			{"unit_def": roster[4], "kind": "add", "level": 1, "count": 0},
		]
		# Called without `await` deliberately: _show_growth_choice() builds
		# the card UI synchronously before its own internal
		# `await growth_offer_picked`, so calling it fire-and-forget runs
		# exactly that build step and then suspends -- perfect for a
		# screenshot, since we never intend to actually pick one here.
		instance._show_growth_choice(offers, "ROUND 4 -- CHOOSE YOUR UPGRADE")
		for i in 6:
			await get_tree().process_frame

	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print("SAVED: ", out_path)
	get_tree().quit()
