extends Node2D
## Runs real menu scenes and selection handlers. It never presses unlock,
## claims rewards, starts a match, or calls a profile-saving method.
const OutputSafety = preload("res://tools/output_safety.gd")
var _checks := 0
var _failures: Array[String] = []
var _output_directory := "res://builds/ui-preview"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_output_directory = arg.substr(10).trim_suffix("/")
	var heroes: Node = load("res://scenes/heroes_screen.tscn").instantiate()
	add_child(heroes)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(heroes._portraits.size() == 10, "Heroes shows all ten units")
	await _capture("heroes-top")
	var hero_scroll: ScrollContainer = heroes.get_node("HeroesScroll")
	hero_scroll.scroll_vertical = 100000
	await get_tree().process_frame
	_check(hero_scroll.scroll_vertical > 0, "Heroes scroll reaches the expanded roster")
	await _capture("heroes-bottom")
	heroes.queue_free()
	await get_tree().process_frame

	var draft: Node = load("res://scenes/draft_screen.tscn").instantiate()
	add_child(draft)
	await get_tree().process_frame
	await get_tree().process_frame
	# Freeze only the presentation countdown; selection uses production handlers.
	draft.set_process(false)
	_check(draft._card_defs.size() == 10, "Draft shows all ten units")
	var roster := UnitDatabase.roster()
	for i in range(6, 10):
		draft._on_unit_picked(roster[i])
	_check(UnitDatabase.valid_draft(draft._hand), "New units form a legal four-type hand")
	draft._on_unit_picked(roster[6])
	_check(draft._hand.size() == 4, "Duplicate selection cannot expand hand")
	_check(not draft._ready_button.disabled, "Ready enables after four distinct picks")
	var draft_scroll: ScrollContainer = draft.get_node("RosterScroll")
	draft_scroll.scroll_vertical = 100000
	await get_tree().process_frame
	await _capture("draft-new-units-picked")
	draft._on_clear_pressed()
	_check(draft._hand.is_empty() and draft._ready_button.disabled, "Clear resets hand and Ready")
	draft.queue_free()
	await get_tree().process_frame

	for unit in roster:
		GameState.detail_unit_path = unit.resource_path
		var detail: Node = load("res://scenes/unit_detail_screen.tscn").instantiate()
		add_child(detail)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(detail._unit_def == unit, "Detail resolves " + unit.display_name)
		_check(detail._ability_headings.size() == 2 and not unit.ability_lv2_name.is_empty() and not unit.ability_lv3_name.is_empty(), "Both tier descriptions exist for " + unit.display_name)
		var detail_scroll: ScrollContainer = detail.get_node("DetailsScroll")
		detail_scroll.scroll_vertical = 100000
		await get_tree().process_frame
		await _capture("detail-" + unit.resource_path.get_file().get_basename())
		detail.queue_free()
		await get_tree().process_frame
	print("UI_ROSTER_PREVIEW: checks=", _checks, " failures=", _failures)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)

func _capture(key: String) -> void:
	await RenderingServer.frame_post_draw
	var output := OutputSafety.checked_png_path(_output_directory + "/" + key + ".png")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
		_failures.append("Rejected screenshot path: " + key)
		return
	var result := get_viewport().get_texture().get_image().save_png(output)
	_check(result == OK, "Screenshot saved: " + key)

