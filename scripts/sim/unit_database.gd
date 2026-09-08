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

const HAND_SIZE := 4


## Everything the player can draft. Order drives the draft screen's button order.
static func roster() -> Array[UnitDefinition]:
	return [ENFORCER, TROOPER, MARKSMAN, DEMOLITIONIST, FIELD_MEDIC]


## A few fixed hands, one picked at random per match -- same canned-hand
## approach the 3D game used since real bot AI is out of scope here too.
## Each hand is 4 DISTINCT types (one type always left out) -- matches the
## "no duplicate types in a hand" rule draft_screen.gd now enforces for the
## human, applied here too rather than just to the UI (2026-08-26; the old
## hands here stacked duplicates like [ENFORCER, ENFORCER, ENFORCER, TROOPER],
## exactly the easy-to-OP-a-type pattern that rule exists to stop).
static func _bot_hands() -> Array:
	return [
		[ENFORCER, TROOPER, MARKSMAN, FIELD_MEDIC],       # no demolitionist
		[TROOPER, MARKSMAN, DEMOLITIONIST, FIELD_MEDIC],  # no enforcer
		[ENFORCER, TROOPER, DEMOLITIONIST, MARKSMAN],     # no field medic
		[ENFORCER, FIELD_MEDIC, MARKSMAN, DEMOLITIONIST], # no trooper
		[ENFORCER, TROOPER, FIELD_MEDIC, DEMOLITIONIST],  # no marksman
	]


## `rng` is passed in so match setup stays reproducible from a single seed.
static func random_bot_hand(rng: RandomNumberGenerator) -> Array[UnitDefinition]:
	var hands := _bot_hands()
	var picked: Array = hands[rng.randi_range(0, hands.size() - 1)]
	var hand: Array[UnitDefinition] = []
	for unit_def in picked:
		hand.append(unit_def)
	return hand
