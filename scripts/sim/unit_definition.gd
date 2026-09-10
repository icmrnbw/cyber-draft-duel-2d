class_name UnitDefinition
extends Resource
## Balance data for one unit type. Ported from the 3D Cyber Draft-Duel project's
## unit_definition.gd -- combat/movement math is presentation-agnostic, so this
## file is unchanged apart from dropping the 3D-only placeholder-art fields
## (body_radius/body_height/scene) that this 2D game doesn't use.
##
## Range model: `preferred_range` is BOTH the attack range and the "advance if the
## enemy is further than this" threshold, and `retreat_range` is the "back off if the
## enemy is closer than this" threshold:
##
##     dist > preferred_range  -> advance
##     dist < retreat_range    -> retreat
##     otherwise               -> hold
##     dist <= preferred_range -> attack (on cooldown)

enum UnitType { MELEE, MID, LONG, SUPPORT }

@export var display_name: String = ""
@export var type: UnitType = UnitType.MELEE
@export var description: String = ""

@export_group("Combat")
@export var hp: float = 100.0
## For a support unit (is_support = true), this is heal power per tick instead of
## damage per hit.
@export var damage_per_hit: float = 10.0
@export var attacks_per_second: float = 1.0
## >0 makes an attack hit every enemy within this radius of the target's position.
@export var splash_radius: float = 0.0
@export var is_support: bool = false
@export var self_defense_damage: float = 0.0
@export var self_defense_range: float = 0.0

@export_group("Movement & Range")
@export var move_speed: float = 4.0
@export var preferred_range: float = 1.5
@export var retreat_range: float = 0.0

@export_group("Level-Up Abilities")
## Data-driven, not unit-specific code -- 0 means "this unit has no such
## ability," so BattleSim can check these generically for any type without
## branching on which .tres it is. Gated by SimUnit.level, which only ever
## rises above 1 via an in-match "level up" growth pick that itself only
## exists if PlayerProfile has the matching Heroes-menu tier unlocked (see
## round_state.gd/player_profile.gd) -- level is never a start-of-match head
## start.
##
## Heavy Strikes: a landed attack has a chance to stagger the target (can't
## attack or move) for stagger_duration seconds. min_level=0 disables it.
@export var stagger_min_level: int = 0
@export var stagger_chance: float = 0.0
@export var stagger_duration: float = 0.0
## Berserk: attack interval shortens as this unit's own HP drops, linearly
## interpolating from 1.0x (full HP) to berserk_max_speed_mult (0% HP).
## min_level=0 disables it; max_speed_mult should be < 1.0 (faster attacks).
@export var berserk_min_level: int = 0
@export var berserk_max_speed_mult: float = 1.0
## Firestorm (2026-09-11, Demolitionist's Lv2+): a landed splash attack also
## leaves a burning ground patch at the impact point for firepatch_duration
## seconds, dealing firepatch_dps to any enemy standing in firepatch_radius
## each tick -- on top of the direct splash hit, not instead of it. Only
## meaningful on a splash_radius > 0 unit (checked in battle_sim.gd's
## _attack()). min_level=0 disables it.
@export var firepatch_min_level: int = 0
@export var firepatch_dps: float = 0.0
@export var firepatch_duration: float = 0.0
@export var firepatch_radius: float = 0.0

@export_group("Art")
@export var sprite: Texture2D
## Real 4-frame breathing loop (neutral/inhale/neutral/exhale, in play
## order) -- replaces the earlier fake "breathing" that was just a sine wave
## scaling/rotating the static idle_sprite in code (2026-09-06: explicitly
## called out as looking bad, since it wasn't actually an animation, just a
## wobble on a flat pasted image). Empty = fall back to a static
## idle_sprite_for_level() frame, same as before this existed.
@export var idle_frames: Array[Texture2D] = []
## Optional spritesheet-derived attack frames (idle/windup/strike/recover, in
## play order). Empty = fall back to the procedural scale-punch/lunge in
## match_controller.gd's _punch(). When set, _punch() plays these instead and
## skips the procedural version -- doing both at once would fight visually.
@export var attack_frames: Array[Texture2D] = []
## Optional 4-frame running cycle, played on a loop while advancing. Empty =
## fall back to the procedural footstep-bounce in match_controller.gd's
## _update_view().
@export var walk_frames: Array[Texture2D] = []
## Optional 4-frame backward-step cycle, played on a loop while retreating
## (moving away from its target/threat -- see _update_view()'s retreat
## direction check). Empty = falls back to walk_frames if set, then the
## procedural bounce.
@export var retreat_frames: Array[Texture2D] = []

@export_group("Level-Up Visuals")
## Optional per-tier overrides of the frame arrays above -- empty (the
## default) falls back to the base tier, so a unit with no level-up ability
## needs none of this set. Use *_frames_for_level()/idle_sprite_for_level()
## below rather than reading these directly -- that's what resolves "which
## tier applies" and falls back correctly.
@export var lv2_idle_frames: Array[Texture2D] = []
@export var lv2_attack_frames: Array[Texture2D] = []
@export var lv2_walk_frames: Array[Texture2D] = []
@export var lv2_retreat_frames: Array[Texture2D] = []
@export var lv3_idle_frames: Array[Texture2D] = []
@export var lv3_attack_frames: Array[Texture2D] = []
@export var lv3_walk_frames: Array[Texture2D] = []
@export var lv3_retreat_frames: Array[Texture2D] = []


func dps() -> float:
	return damage_per_hit * attacks_per_second


func attack_interval() -> float:
	return 1.0 / attacks_per_second if attacks_per_second > 0.0 else INF


func idle_frames_for_level(level: int) -> Array[Texture2D]:
	if level >= 3 and not lv3_idle_frames.is_empty():
		return lv3_idle_frames
	if level >= 2 and not lv2_idle_frames.is_empty():
		return lv2_idle_frames
	return idle_frames


func attack_frames_for_level(level: int) -> Array[Texture2D]:
	if level >= 3 and not lv3_attack_frames.is_empty():
		return lv3_attack_frames
	if level >= 2 and not lv2_attack_frames.is_empty():
		return lv2_attack_frames
	return attack_frames


func walk_frames_for_level(level: int) -> Array[Texture2D]:
	if level >= 3 and not lv3_walk_frames.is_empty():
		return lv3_walk_frames
	if level >= 2 and not lv2_walk_frames.is_empty():
		return lv2_walk_frames
	return walk_frames


func retreat_frames_for_level(level: int) -> Array[Texture2D]:
	if level >= 3 and not lv3_retreat_frames.is_empty():
		return lv3_retreat_frames
	if level >= 2 and not lv2_retreat_frames.is_empty():
		return lv2_retreat_frames
	return retreat_frames


## The idle/portrait texture for this level -- just that tier's first attack
## frame, same convention the base `sprite` field already follows (it's
## literally attack_frames[0]).
func idle_sprite_for_level(level: int) -> Texture2D:
	var frames := attack_frames_for_level(level)
	return frames[0] if not frames.is_empty() else sprite
