class_name SimUnit
extends RefCounted
## One unit's runtime state inside BattleSim. Pure data -- no Node, no rendering.
## Ported verbatim from the 3D project's sim_unit.gd (presentation-agnostic).

var id: int = -1
var team: int = 0  ## 0 = player (side A), 1 = opponent (side B)
var def: UnitDefinition

var power_multiplier: float = 1.0
## Discrete level, separate from power_multiplier (which is already derived
## from it via RoundState.power_for_level() before reaching BattleSim) --
## kept here too because ability thresholds (def.stagger_min_level etc.) are
## checked against the discrete level, not the continuous stat multiplier.
var level: int = 1

var hp: float = 0.0
## Arena-plane position: x = spread axis, y = approach axis (see BattleSim).
var pos: Vector2 = Vector2.ZERO
## For combat units: nearest enemy. For support units (def.is_support): the
## neediest injured ally -- see BattleSim._acquire_targets().
var target_id: int = -1
## Support units only: nearest enemy, tracked separately from target_id.
var threat_id: int = -1
var attack_cooldown: float = 0.0
## Heavy Strikes (see UnitDefinition.stagger_*): >0 means this unit can't
## attack or move this tick. Counts down by TICK_DELTA every tick regardless
## of what set it, so it works the same no matter which unit's ability
## triggered it.
var stagger_timer: float = 0.0
var alive: bool = true

var pending_damage: float = 0.0
var pending_heal: float = 0.0


func max_hp() -> float:
	return def.hp * power_multiplier


func hp_fraction() -> float:
	var max_h := max_hp()
	return clampf(hp / max_h, 0.0, 1.0) if max_h > 0.0 else 0.0
