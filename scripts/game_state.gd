extends Node
## Autoload. Carries the drafted hand + bot hand + match seed from the draft
## screen to the match scene -- the 2D game's minimal equivalent of the 3D
## project's GameManager autoload (no online play, no menu stack here yet, so
## just the handful of fields the scene transition actually needs).
##
## `ranked` + `casual_opponent_name` (2026-09-06): every match is actually
## against UnitDatabase.random_bot_hand() -- there is no real PvP in this
## project. Ranked stays an honestly-framed solo difficulty ladder (no fake
## opponent, see arena_database.gd/player_profile.gd). Casual is where the
## "Searching for opponent" theater lives instead (matchmaking_screen.gd) --
## low-stakes, no rating on the line, so there's nothing to feel cheated out
## of if a player ever suspects the opponent isn't real. Set by whichever
## main-menu button was pressed; persists across a rematch (which calls
## start_match() directly, without re-entering either flow).

var ranked: bool = true
var casual_opponent_name: String = ""

var player_hand: Array[UnitDefinition] = []
var bot_hand: Array[UnitDefinition] = []
var match_seed: int = 1

## Set by whichever screen opened unit_detail_screen.tscn (Heroes, Draft) so
## it knows which unit to show -- a resource path rather than the
## UnitDefinition itself since scene changes are stateless and every .tres
## is already addressed this way throughout the project (see
## unit_database.gd/player_profile.gd).
var detail_unit_path: String = ""


func start_match(p_player_hand: Array[UnitDefinition]) -> void:
	player_hand = p_player_hand
	var setup_rng := RandomNumberGenerator.new()
	setup_rng.randomize()
	match_seed = setup_rng.randi()
	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = match_seed
	bot_hand = UnitDatabase.random_bot_hand(bot_rng)
	get_tree().change_scene_to_file("res://scenes/match.tscn")
