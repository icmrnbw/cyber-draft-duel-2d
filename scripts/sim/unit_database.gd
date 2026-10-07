class_name UnitDatabase
extends RefCounted
## Ported from the 3D project's unit_database.gd -- the roster of draftable
## units, plus the bot's canned hands. Was a Node autoload there (for a
## project-wide `UnitDatabase.roster` reference); here it's just a RefCounted
## helper with static accessors, since nothing else in this project needs
## autoload-style per-instance state.

const ENFORCER := preload("res://resources/enforcer.tres")
const TROOPER := preload("res://resources/trooper.tres")
const MARKSMAN := preload("res://resources/marksman.tres")
const DEMOLITIONIST := preload("res://resources/demolitionist.tres")
const FIELD_MEDIC := preload("res://resources/field_medic.tres")
const BULWARK := preload("res://resources/bulwark.tres")
const PHASEBLADE := preload("res://resources/phaseblade.tres")
const CRYOTEK := preload("res://resources/cryotek.tres")
const ARCRELAY := preload("res://resources/arcrelay.tres")
const NULLBREAKER := preload("res://resources/nullbreaker.tres")

const HAND_SIZE := 4


## Everything the player can draft. Order drives the draft screen's button order.
static func roster() -> Array[UnitDefinition]:
	return [ENFORCER, TROOPER, MARKSMAN, DEMOLITIONIST, FIELD_MEDIC,
		BULWARK, PHASEBLADE, CRYOTEK, ARCRELAY, NULLBREAKER]


## Named valid archetypes are shared with developer balance tools. Roster
## expansion can add archetypes without changing draft size or sampling logic.
static func archetype_hands() -> Dictionary:
	return {
		"balanced": [ENFORCER, TROOPER, MARKSMAN, FIELD_MEDIC],
		"ranged_sustain": [TROOPER, MARKSMAN, DEMOLITIONIST, FIELD_MEDIC],
		"pressure": [ENFORCER, TROOPER, DEMOLITIONIST, MARKSMAN],
		"heavy_sustain": [ENFORCER, FIELD_MEDIC, MARKSMAN, DEMOLITIONIST],
		"area_sustain": [ENFORCER, TROOPER, FIELD_MEDIC, DEMOLITIONIST],
		"control": [BULWARK, CRYOTEK, ARCRELAY, FIELD_MEDIC],
		"mobility": [ENFORCER, PHASEBLADE, TROOPER, FIELD_MEDIC],
		"anti_armor": [BULWARK, NULLBREAKER, MARKSMAN, FIELD_MEDIC],
	}


static func valid_draft(hand: Array) -> bool:
	if hand.size() != HAND_SIZE:
		return false
	var seen := {}
	var available := roster()
	for unit_def in hand:
		if not unit_def is UnitDefinition or unit_def not in available or seen.has(unit_def):
			return false
		seen[unit_def] = true
	return true


static func all_distinct_hands() -> Array:
	var hands: Array = []
	_collect_hands(roster(), 0, [], hands)
	return hands


static func _collect_hands(available: Array[UnitDefinition], start: int, prefix: Array, hands: Array) -> void:
	if prefix.size() == HAND_SIZE:
		hands.append(prefix.duplicate())
		return
	for i in range(start, available.size() - (HAND_SIZE - prefix.size()) + 1):
		var next := prefix.duplicate()
		next.append(available[i])
		_collect_hands(available, i + 1, next, hands)


## `rng` is passed in so match setup stays reproducible from a single seed.
static func random_bot_hand(rng: RandomNumberGenerator) -> Array[UnitDefinition]:
	var archetypes: Array = archetype_hands().values().filter(func(hand: Array) -> bool: return valid_draft(hand))
	if not archetypes.is_empty() and rng.randf() < 0.5:
		var hand: Array[UnitDefinition] = []
		hand.assign(archetypes[rng.randi_range(0, archetypes.size() - 1)])
		return hand
	# Seeded Fisher-Yates; Array.shuffle() would use unrelated global RNG.
	var pool := roster().duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary: UnitDefinition = pool[i]
		pool[i] = pool[j]
		pool[j] = temporary
	var sampled: Array[UnitDefinition] = []
	sampled.assign(pool.slice(0, HAND_SIZE))
	return sampled
