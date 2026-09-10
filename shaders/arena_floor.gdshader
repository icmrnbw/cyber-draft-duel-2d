shader_type canvas_item;

// Animated neon hex-grid battle floor -- procedural (no art asset, zero
// Meshy spend), replacing the earlier static per-arena Meshy image. Math
// prototyped and verified in Python/numpy first (project convention) before
// porting here, since a hex-grid SDF is easy to get subtly wrong: see
// tools/ for the reference render this was checked against.
//
// Technique: iq's classic hex-tiling trick (two interleaved rectangular
// grids, pick whichever cell center is closer) gives a per-pixel distance
// to the nearest hex CENTER in `gv`; a dot-product/max combination of that
// vector's components gives the distance to the nearest hex EDGE, which
// peaks at 0.5 at a cell boundary -- thresholding near that value draws thin
// glowing edge lines. A radial ring keyed off TIME sweeps outward from the
// screen center for the "pulse," continuously re-triggering via mod().

uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform float hex_scale : hint_range(10.0, 150.0) = 60.0;
uniform vec4 color_a : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.65, 0.45, 0.95, 1.0);
uniform vec4 bg_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform float base_glow : hint_range(0.0, 1.0) = 0.12;
uniform float pulse_speed : hint_range(0.0, 20.0) = 3.5;
uniform float pulse_spacing : hint_range(4.0, 40.0) = 13.0;
uniform float pulse_width : hint_range(0.1, 3.0) = 0.7;
uniform float pulse_strength : hint_range(0.0, 4.0) = 1.6;

const vec2 HEX_R = vec2(1.0, 1.73205);

float hex_edge_dist(vec2 p) {
	p = abs(p);
	float c = p.x * 0.5 + p.y * 0.8660254;
	c = max(c, p.x);
	return c;
}

vec2 hex_center_offset(vec2 uv) {
	vec2 h = HEX_R * 0.5;
	vec2 a = mod(uv, HEX_R) - h;
	vec2 b = mod(uv - h, HEX_R) - h;
	return dot(a, a) < dot(b, b) ? a : b;
}

void fragment() {
	vec2 centered = (UV - 0.5) * rect_size;
	vec2 grid_uv = centered / hex_scale;

	vec2 gv = hex_center_offset(grid_uv);
	float d = hex_edge_dist(gv);
	float edge = 1.0 - clamp(abs(d - 0.5) / 0.04, 0.0, 1.0);

	float r = length(centered) / hex_scale;
	float pulse_r = mod(TIME * pulse_speed, pulse_spacing);
	float pulse = exp(-pow(r - pulse_r, 2.0) / pulse_width);

	float glow = edge * (base_glow + pulse * pulse_strength);

	float t = clamp(r / 10.0, 0.0, 1.0);
	vec3 line_color = mix(color_a.rgb, color_b.rgb, t);

	vec3 color = mix(bg_color.rgb, line_color * 1.3, clamp(glow, 0.0, 1.0));
	COLOR = vec4(color, 1.0);
}
