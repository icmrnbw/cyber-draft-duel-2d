shader_type canvas_item;

// Slowly rotates the hue of a painted texture over time (the classic
// hue-rotation matrix, same math as CSS's hue-rotate filter) -- applied to
// UITheme.build_painted_panel()'s Meshy-generated glass-panel art so its
// baked cyan-violet border gradient keeps drifting through color instead of
// sitting static, per the user's "dynamically gradienting" request. Applied
// to the whole texture rather than masking just the border: the dark glass
// fill is desaturated enough that rotating its hue barely reads, so no mask
// is needed to keep the fill looking unaffected.

uniform float speed : hint_range(0.0, 2.0) = 0.3;
// A full rotation sweeps through green/yellow/red, which clashes with the
// rest of the UI's fixed cyan-violet palette (currency pill, titles, etc).
// Oscillating within a bounded arc keeps the gradient shifting while
// staying in the cyan-blue-violet-magenta family everything else uses.
// Cyan sits close to green on the hue wheel (~180 vs ~120deg), so even a
// "bounded" +/-31deg swing was enough to visibly tip it green on one side
// of the oscillation (confirmed by screenshotting mid-swing) -- narrowed to
// stay safely within the blue/violet family on both sides.
uniform float max_angle : hint_range(0.0, 1.57) = 0.3;

vec3 hue_rotate(vec3 color, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	mat3 base = mat3(
		vec3(0.299, 0.299, 0.299),
		vec3(0.587, 0.587, 0.587),
		vec3(0.114, 0.114, 0.114)
	);
	mat3 cos_part = mat3(
		vec3(0.701, -0.299, -0.300),
		vec3(-0.587, 0.413, -0.588),
		vec3(-0.114, -0.114, 0.886)
	);
	mat3 sin_part = mat3(
		vec3(0.168, -0.328, 1.250),
		vec3(0.330, 0.035, -1.050),
		vec3(-0.497, 0.292, -0.203)
	);
	mat3 m = base + cos_part * c + sin_part * s;
	return clamp(m * color, 0.0, 1.0);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float angle = sin(TIME * speed) * max_angle;
	tex.rgb = hue_rotate(tex.rgb, angle);
	COLOR = tex;
}
