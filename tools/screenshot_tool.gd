extends Node2D
## One-off visual QA tool (throwaway pattern established this project): loads
## a target scene headed (needs a real window, not --headless, for viewport
## capture) and dumps a PNG so screenshots can be compared directly against
## reference mockups without needing a phone/emulator.
## Usage: Godot --resolution 720x1280 --quit-after N res://tools/screenshot_tool.tscn -- --scene=res://scenes/main_menu.tscn --out=C:/path/out.png

func _ready() -> void:
	var scene_path := "res://scenes/main_menu.tscn"
	var out_path := "user://screenshot.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			scene_path = arg.substr(8)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)

	if scene_path == "res://scenes/unit_detail_screen.tscn" and GameState.detail_unit_path == "":
		GameState.detail_unit_path = UnitDatabase.roster()[2].resource_path

	if scene_path == "res://scenes/match.tscn":
		# Set the fields GameState.start_match() would set WITHOUT calling it --
		# it calls change_scene_to_file() itself, which frees this very node
		# (the running main scene) out from under the still-executing _ready(),
		# killing get_tree() on the next await. Loading match.tscn ourselves
		# below (same as every other scene here) avoids that entirely.
		var hand: Array[UnitDefinition] = UnitDatabase.roster().slice(0, 4)
		GameState.player_hand = hand
		var setup_rng := RandomNumberGenerator.new()
		setup_rng.randomize()
		GameState.match_seed = setup_rng.randi()
		var bot_rng := RandomNumberGenerator.new()
		bot_rng.seed = GameState.match_seed
		GameState.bot_hand = UnitDatabase.random_bot_hand(bot_rng)

	var scene: PackedScene = load(scene_path)
	var instance: Node = scene.instantiate()
	get_tree().root.add_child.call_deferred(instance)
	await get_tree().process_frame
	await get_tree().process_frame

	# Let extra frames pass for match.tscn so the sim/units settle into a
	# representative mid-setup frame before capture.
	var settle_frames := 40 if scene_path == "res://scenes/match.tscn" else 10
	for i in settle_frames:
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
