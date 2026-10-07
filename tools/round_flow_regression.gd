extends "res://scripts/match_controller.gd"
## Exercise production round routing with presentation/rewards replaced in memory.
var _started_rounds := 0
var _growth_calls := 0
var _finished_matches := 0
var _result_calls := 0
var _failures: Array[String] = []

func _ready() -> void:
	_round_state = RoundState.new()
	var hand: Array[UnitDefinition] = [UnitDatabase.ENFORCER]
	_round_state.init(hand, hand, 914)
	_sim = BattleSim.new()
	_sim.setup(hand, hand, 914)
	_sim.result = BattleSim.Result.DRAW
	for round_index in range(3):
		for _retry in range(RoundState.MAX_DRAW_RETRIES):
			_round_state.record_round_result(BattleSim.Result.DRAW)
		await _on_round_finished()
		if _round_state.lives_a != 2 - round_index or _round_state.lives_b != 2 - round_index:
			_failures.append("Exact draw must charge both lives")
	if _result_calls != 3 or _growth_calls != 2 or _started_rounds != 2 or _finished_matches != 1:
		_failures.append("Resolved draws must route through result, growth and match completion")
	if not _round_state.is_match_over() or _round_state.winner_team() != -1:
		_failures.append("Three resolved drawn rounds must end as a match draw")
	# Reproduce cleanup during a pending spritesheet animation. Its tween must
	# die with its sprite, rather than firing callbacks against freed views.
	var view := _build_unit_view(_sim.units[0])
	_views.append(view)
	_play_attack_frames(view)
	await get_tree().process_frame
	_free_views()
	await get_tree().create_timer(0.6).timeout
	if not get_tree().get_processed_tweens().is_empty():
		_failures.append("Animation tweens survived view cleanup")
	print("ROUND_FLOW: results=", _result_calls, " growth=", _growth_calls, " rounds_started=", _started_rounds, " finished=", _finished_matches, " failures=", _failures)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _process(_delta: float) -> void:
	pass

func _show_round_result_screen(_a: int, _b: int) -> void:
	_result_calls += 1

func _resolve_growth_picks() -> void:
	_growth_calls += 1

func _start_round() -> void:
	_started_rounds += 1

func _show_match_result(_forfeited: bool = false) -> void:
	_finished_matches += 1
