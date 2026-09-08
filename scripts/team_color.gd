class_name TeamColor
extends RefCounted
## Reusable, zero-authoring-cost team identity: every unit keeps its own
## fixed base art/color (see project_2d_pivot notes -- base color = "what
## unit", not "whose"), and this shader draws a team-colored rim-light glow
## around the sprite's silhouette at draw time. No separate texture per team,
## no extra Meshy generation cost per color, and no art changes needed even
## for new units -- apply this to any Sprite2D and it's teamed for free.

const SHADER := preload("res://shaders/team_trim_2d.gdshader")

const TEAM_A := Color(0.15, 0.75, 1.0)  # cyan, matches the 3D game's TEAM_A_COLOR
const TEAM_B := Color(1.0, 0.42, 0.2)   # orange, matches the 3D game's TEAM_B_COLOR


static func apply(sprite: Sprite2D, team_color: Color) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("team_color", team_color)
	sprite.material = mat


## For menu contexts (Heroes/draft screens) that want the same vibrance
## recolor as in-battle units but have no "team" to show a rim glow for --
## rim_strength=0.0 skips the glow branch's visible output entirely while
## the vibrance boost (applied unconditionally in the shader, before the rim
## branch) still runs. Works on any CanvasItem (TextureRect included, not
## just Sprite2D), since the shader itself is shader_type canvas_item.
static func apply_vibrance_only(node: CanvasItem) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("rim_strength", 0.0)
	node.material = mat


static func color_for_side(side: int) -> Color:
	return TEAM_A if side == 0 else TEAM_B
