class_name ArenaDatabase
extends RefCounted
## Arenas are rating brackets wearing a costume: each one owns a name, a
## minimum rating, and its own battlefield art. Climbing rating moves you
## through them, which is the whole retention hook -- the main menu shows
## progress toward the next one, so there's always a visible "almost there."
##
## Same static-accessor RefCounted shape as unit_database.gd (no autoload
## needed, nothing here has per-instance state).

## Ordered lowest -> highest. The first entry's min_rating is deliberately
## PlayerProfile.RATING_FLOOR (800), NOT 0: progress_to_next() measures from
## the current arena's floor, so a 0 here would span 0->1150 and show a
## brand-new player (starting at 1000) an ~87%-full bar on their very first
## launch -- which reads as "nearly done" and kills the exact "almost there"
## pull the bar exists to create. Anchoring to the real reachable floor makes
## that same player start around 57%, and someone who has bottomed out at the
## floor start at 0%.
## `glow_a`/`glow_b` feed the procedural animated hex-grid battle floor
## (shaders/arena_floor.gdshader, 2026-09-10) -- replaced the earlier static
## per-arena Meshy image (a floating rock platform) with a code-driven,
## actually-animated floor matching the neon UI language exactly, at zero
## art-generation cost. Each arena keeps a distinct color identity through
## just these two colors rather than a whole new image.
const ARENAS := [
	{"name": "Asteroid Belt", "min_rating": 800, "glow_a": Color(0.3, 0.85, 1.0), "glow_b": Color(0.65, 0.45, 0.95)},
	{"name": "Frozen Reach", "min_rating": 1150, "glow_a": Color(0.55, 0.9, 1.0), "glow_b": Color(0.75, 0.55, 1.0)},
	{"name": "Molten Core", "min_rating": 1350, "glow_a": Color(1.0, 0.55, 0.25), "glow_b": Color(0.75, 0.3, 0.95)},
]


static func arena_for_rating(rating: int) -> Dictionary:
	var best: Dictionary = ARENAS[0]
	for a in ARENAS:
		if rating >= int(a["min_rating"]):
			best = a
	return best


static func arena_index_for_rating(rating: int) -> int:
	var idx := 0
	for i in range(ARENAS.size()):
		if rating >= int(ARENAS[i]["min_rating"]):
			idx = i
	return idx


## The next arena up, or an empty dict if already in the top one.
static func next_arena(rating: int) -> Dictionary:
	var idx := arena_index_for_rating(rating)
	if idx + 1 >= ARENAS.size():
		return {}
	return ARENAS[idx + 1]


## 0.0-1.0 progress from the current arena's floor toward the next one's
## threshold. Returns 1.0 in the top arena (nothing left to climb toward).
static func progress_to_next(rating: int) -> float:
	var idx := arena_index_for_rating(rating)
	if idx + 1 >= ARENAS.size():
		return 1.0
	var current_min := float(ARENAS[idx]["min_rating"])
	var next_min := float(ARENAS[idx + 1]["min_rating"])
	var span := next_min - current_min
	if span <= 0.0:
		return 1.0
	return clampf((float(rating) - current_min) / span, 0.0, 1.0)
