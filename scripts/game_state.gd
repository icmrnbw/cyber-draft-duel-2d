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

## The squad actually deployed round 1 -- since 2026-09-11 this can be any
## multiset of player_drafted_types (e.g. 2 Enforcers + 2 Troopers), chosen
## on deploy_screen.tscn, not automatically one of each drafted type.
var player_hand: Array[UnitDefinition] = []
## The 4 DISTINCT types drafted on draft_screen.gd -- kept separate from
## player_hand (what's deployed) since RoundState.type_pool_a (which "add"
## growth offers draw from all match) is still every drafted type, whether
## or not it was part of the initial deployment.
var player_drafted_types: Array[UnitDefinition] = []
var bot_hand: Array[UnitDefinition] = []
var match_seed: int = 1

## Set by whichever screen opened unit_detail_screen.tscn (Heroes, Draft) so
## it knows which unit to show -- a resource path rather than the
## UnitDefinition itself since scene changes are stateless and every .tres
## is already addressed this way throughout the project (see
## unit_database.gd/player_profile.gd).
var detail_unit_path: String = ""


## `p_drafted_types` defaults to `p_player_hand` itself (falls back to
## "type pool == whatever's deployed") for any caller that hasn't been
## updated to pass the real 4 drafted types separately -- degrades safely
## rather than crashing on a missing argument.
func start_match(p_player_hand: Array[UnitDefinition], p_drafted_types: Array[UnitDefinition] = []) -> void:
	player_hand = p_player_hand
	player_drafted_types = p_drafted_types if not p_drafted_types.is_empty() else p_player_hand
	var setup_rng := RandomNumberGenerator.new()
	setup_rng.randomize()
	match_seed = setup_rng.randi()
	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = match_seed
	bot_hand = UnitDatabase.random_bot_hand(bot_rng)
	get_tree().change_scene_to_file("res://scenes/match.tscn")
