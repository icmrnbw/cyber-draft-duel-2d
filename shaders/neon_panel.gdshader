shader_type canvas_item;

// Rounded-rect panel with a diagonal two-color gradient, used for both the
// glowing gradient BORDER Draft Showdown's own reference doesn't use, but
// this mockup does -- StyleBoxFlat only does solid colors, so anything
// gradient (borders, CTA button fills) needs a shader. `filled` toggles
// between a bordered-outline card and a solid gradient-fill button; both
// share the same rounded-rect SDF and diagonal gradient math.

uniform vec2 rect_size = vec2(200.0, 60.0);
uniform float radius : hint_range(0.0, 80.0) = 18.0;
uniform vec4 color_a : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.65, 0.45, 0.95, 1.0);
uniform float border_width : hint_range(0.0, 20.0) = 2.5;
uniform bool filled = false;
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;

float sdf_rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = (UV - 0.5) * rect_size;
	vec2 half_size = rect_size * 0.5;
	float d = sdf_rounded_box(px, half_size, radius);

	float t = clamp((px.x + px.y) / (rect_size.x + rect_size.y) + 0.5, 0.0, 1.0);
	vec3 grad_color = mix(color_a.rgb, color_b.rgb, t);

	float shape_alpha;
	if (filled) {
		shape_alpha = 1.0 - smoothstep(0.0, 1.5, d);
	} else {
		shape_alpha = 1.0 - smoothstep(float(border_width) - 1.0, float(border_width) + 1.0, abs(d));
		shape_alpha *= step(d, float(border_width) + 2.0);
	}

	// Soft outward glow beyond the shape's own edge -- reads as the neon
	// bloom the reference has around every card/button, not just a flat
	// border line.
	float outside = max(d, 0.0);
	float glow = exp(-outside * 0.25) * glow_strength * step(0.0, d);

	float alpha = clamp(shape_alpha + glow * 0.5, 0.0, 1.0);
	COLOR = vec4(grad_color, alpha);
}
