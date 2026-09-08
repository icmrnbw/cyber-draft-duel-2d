extends Node
## Autoload. Persistent, out-of-match, per-unit-TYPE progression, saved to
## disk so it survives between app launches -- the first persistence this
## project has ever needed.
##
## NOT a starting-level boost (2026-08-26 redesign): a unit always starts a
## match at level 1 regardless of anything unlocked here. This purely GATES
## which "level up" cards round_state.gd's roll_offers() is even allowed to
## roll during a match -- see match_controller.gd's _unlocked_levels_by_path().
## Two unlockable tiers per type, bought in order: tier 1 lets a Lv.1 stack
## level up to Lv.2 in-match, tier 2 (needs tier 1 first) lets a Lv.2 stack
## reach Lv.3. RoundState.MAX_LEVEL (3) is the shared ceiling both systems
## agree a level means the same thing against.

const SAVE_PATH := "user://player_profile.json"
const MAX_TIERS := RoundState.MAX_LEVEL - 1  # 2: unlock Lv.2, unlock Lv.3
## Cost to unlock tier 1, then tier 2 -- placeholders, deliberately steep
## since each tier is meant to be a substantial, rare purchase (only 2 exist
## per unit type), not a long grindy ladder.
const TIER_COSTS := [150, 350]

## Ladder rating, drives which arena you're in (see arena_database.gd).
## Starts mid-range rather than at 0 so an early loss streak can actually
## move DOWN without immediately flooring out.
const STARTING_RATING := 1000
const RATING_WIN := 25
const RATING_LOSS := 18
## Never fall below this -- a hard floor keeps a bad run from becoming an
## unrecoverable hole, which is the fastest way to lose a new player.
const RATING_FLOOR := 800

var currency: int = 0
var rating: int = STARTING_RATING
## Unix day-number of the last claimed daily ad reward (see can_claim_daily()).
var last_daily_claim_day: int = -1
## unit_def.resource_path -> int, 0..MAX_TIERS. Keyed by resource path (not a
## new UnitDefinition field) since every .tres is already addressed that way
## throughout the project (see unit_database.gd).
var _unlocked_tiers: Dictionary = {}


func _ready() -> void:
	_load()


func unlocked_tier(unit_def: UnitDefinition) -> int:
	return int(_unlocked_tiers.get(unit_def.resource_path, 0))


## The highest level this type is allowed to reach in a match -- what
## round_state.gd's roll_offers() actually consumes.
func max_unlocked_level(unit_def: UnitDefinition) -> int:
	return 1 + unlocked_tier(unit_def)


## -1 once fully unlocked (nothing left to buy).
func next_tier_cost(unit_def: UnitDefinition) -> int:
	var tier := unlocked_tier(unit_def)
	if tier >= MAX_TIERS:
		return -1
	return TIER_COSTS[tier]


func can_unlock_next_tier(unit_def: UnitDefinition) -> bool:
	var cost := next_tier_cost(unit_def)
	return cost >= 0 and currency >= cost


func unlock_next_tier(unit_def: UnitDefinition) -> bool:
	if not can_unlock_next_tier(unit_def):
		return false
	currency -= next_tier_cost(unit_def)
	_unlocked_tiers[unit_def.resource_path] = unlocked_tier(unit_def) + 1
	_save()
	return true


func add_currency(amount: int) -> void:
	currency += amount
	_save()


## Applies a match result to the ladder rating and returns the signed delta,
## so the result screen can show "+25" / "-18" without recomputing it.
func apply_match_result(won: bool) -> int:
	var before := rating
	rating = maxi(RATING_FLOOR, rating + (RATING_WIN if won else -RATING_LOSS))
	_save()
	return rating - before


func current_arena() -> Dictionary:
	return ArenaDatabase.arena_for_rating(rating)


## Days since the Unix epoch, in local time -- the daily reward resets on a
## real calendar-day boundary rather than a rolling 24h timer, which is what
## players expect from a "daily" and is trivially cheaper to reason about.
func _today_day_number() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func can_claim_daily() -> bool:
	return last_daily_claim_day != _today_day_number()


func claim_daily(amount: int) -> bool:
	if not can_claim_daily():
		return false
	last_daily_claim_day = _today_day_number()
	currency += amount
	_save()
	return true


## Wipes local progression back to a fresh-install state (settings_screen.gd
## exposes this behind a two-tap confirm). Deliberately does NOT touch
## GameSettings -- a player resetting progress didn't ask to have their sound
## preference flipped back on.
func reset_progress() -> void:
	currency = 0
	rating = STARTING_RATING
	last_daily_claim_day = -1
	_unlocked_tiers = {}
	_save()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	currency = int(data.get("currency", 0))
	# Defaults keep an older save (written before rating/daily existed) valid
	# instead of wiping it -- a save-format change should never cost a player
	# their progress.
	rating = int(data.get("rating", STARTING_RATING))
	last_daily_claim_day = int(data.get("last_daily_claim_day", -1))
	var tiers_raw = data.get("unlocked_tiers", {})
	if typeof(tiers_raw) == TYPE_DICTIONARY:
		_unlocked_tiers = tiers_raw


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"currency": currency,
		"rating": rating,
		"last_daily_claim_day": last_daily_claim_day,
		"unlocked_tiers": _unlocked_tiers,
	}))
	f.close()
