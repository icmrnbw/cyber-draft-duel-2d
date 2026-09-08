shader_type canvas_item;
// Connects the two spawn platforms: a vertical energy beam that cycles
// through team A's color -> team B's color -> their additive mix -> back to
// team A, repeating both along the beam's length and scrolling over time so
// it reads as flowing energy, not a static print.

uniform vec3 color_a : source_color = vec3(0.15, 0.75, 1.0);
uniform vec3 color_b : source_color = vec3(1.0, 0.42, 0.2);
uniform float repeats : hint_range(1.0, 8.0) = 3.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.35;

vec3 cycle_color(float t) {
	vec3 mix_color = (color_a + color_b) * 0.5;
	t = fract(t);
	if (t < 1.0 / 3.0) {
		return mix(color_a, color_b, t * 3.0);
	} else if (t < 2.0 / 3.0) {
		return mix(color_b, mix_color, (t - 1.0 / 3.0) * 3.0);
	}
	return mix(mix_color, color_a, (t - 2.0 / 3.0) * 3.0);
}

void fragment() {
	float cycle_pos = UV.y * repeats - TIME * scroll_speed;
	vec3 core_color = cycle_color(cycle_pos);

	// Bright thin core fading to soft glow at the strip's horizontal edges.
	float dist_from_center = abs(UV.x - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.0, 0.25, dist_from_center);
	float glow = 1.0 - smoothstep(0.0, 1.0, dist_from_center);
	float alpha = clamp(core * 0.9 + glow * 0.35, 0.0, 1.0);

	COLOR = vec4(core_color * (0.7 + core * 0.6), alpha);
}
