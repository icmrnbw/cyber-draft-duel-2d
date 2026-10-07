extends "res://scripts/match_controller.gd"
## Developer-only tier/state contact sheet using the production view builder,
## team shader, frame resolvers and HP-bar placement. Never starts a match or
## changes PlayerProfile. --unit=enforcer --frame=0 --out=res://builds/preview.png
var _preview_frame := -1
var _preview_clock := 0.0
var _preview_entries: Array[Dictionary] = []
var _preview_out := ""
var _capture_cycle := false

func _ready() -> void:
	var unit_name := "enforcer"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--unit="):
			unit_name = arg.substr(7)
		elif arg.begins_with("--frame="):
			_preview_frame = clampi(int(arg.substr(8)), 0, 3)
		elif arg.begins_with("--out="):
			_preview_out = arg.substr(6)
		elif arg == "--capture-cycle":
			_capture_cycle = true
	var def: UnitDefinition
	for candidate in UnitDatabase.roster():
		if candidate.resource_path.get_file().get_basename() == unit_name:
			def = candidate
	if def == null:
		push_error("Unknown preview unit: " + unit_name)
		get_tree().quit(1)
		return
	RenderingServer.set_default_clear_color(Color("101a29"))
	_preview_label(def.display_name + " / tier animation QA", Vector2(24, 20), 28)
	_preview_label("Production shader + 512 px frame scale + HP bars", Vector2(24, 60), 17)
	_unit_scale = 0.32
	for level in range(1, 4):
		var x := 120.0 + (level - 1) * 240.0
		_preview_label("Lv%d" % level, Vector2(x - 20, 104), 23)
		for state_index in range(4):
			var state_name: String = ["idle", "attack", "walk", "retreat"][state_index]
			var unit := SimUnit.new()
			unit.id = _preview_entries.size()
			unit.def = def
			unit.level = level
			unit.hp = def.hp
			unit.team = 0 if level < 3 else 1
			unit.pos = Vector2(x, 265.0 + state_index * 278.0)
			var view := _build_unit_view(unit)
			_update_view(view)
			view.idle_blend.visible = false
			_preview_entries.append({"view": view, "state": state_name})
			_preview_label(state_name, Vector2(x - 45, unit.pos.y + 95), 19)
	if not _preview_out.is_empty():
		for capture_index in range(4 if _capture_cycle else 1):
			if _capture_cycle:
				_preview_frame = capture_index
			var destination := _preview_out.get_basename() + "-frame%d.png" % capture_index if _capture_cycle else _preview_out
			if not await _capture_preview(destination):
				return
		get_tree().quit()

func _capture_preview(destination: String) -> bool:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := preload("res://tools/output_safety.gd").checked_png_path(destination)
		if output.is_empty():
			push_error("Preview output must be inside res://builds/")
			get_tree().quit(1)
			return false
		var directory_error := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		if directory_error != OK:
			push_error("Preview directory failed: %s" % directory_error)
			get_tree().quit(1)
			return false
		var save_error := get_viewport().get_texture().get_image().save_png(output)
		if save_error != OK:
			push_error("Preview save failed: %s" % save_error)
			get_tree().quit(1)
			return false
		print("PREVIEW_SAVED: ", output)
		return true

func _process(delta: float) -> void:
	_preview_clock += delta
	var frame := _preview_frame if _preview_frame >= 0 else int(_preview_clock / 0.18) % 4
	for entry in _preview_entries:
		var view: Dictionary = entry.view
		var unit: SimUnit = view.unit
		var frames: Array[Texture2D] = []
		match entry.state:
			"idle": frames = unit.def.idle_frames_for_level(unit.level)
			"attack": frames = unit.def.attack_frames_for_level(unit.level)
			"walk": frames = unit.def.walk_frames_for_level(unit.level)
			"retreat": frames = unit.def.retreat_frames_for_level(unit.level)
		if not frames.is_empty():
			view.sprite.texture = frames[frame % frames.size()]

func _sim_to_screen(pos: Vector2) -> Vector2:
	return pos

func _preview_label(value: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
