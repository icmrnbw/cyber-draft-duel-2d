shader_type canvas_item;

// Animated battle floor. Two modes, chosen by `use_texture`:
//  - textured (2026-09-10, current default): samples the node's own bound
//    TEXTURE (a real painted arena image -- see arena_floor_hex_reference.png,
//    cropped from a user-provided reference render) as the base, then adds
//    an animated radial glow pulse on top so a static image still reads as
//    alive. Deliberately just a traveling glow rather than a full drawn hex
//    grid here, since the reference art already has its own baked hex-panel
//    detail and beam -- overlaying a second competing grid pattern fought it.
//  - procedural (the original version of this shader, use_texture=false):
//    a fully code-drawn animated neon hex-grid with no art asset at all.
//    Math prototyped and verified in Python/numpy first (project
//    convention) before porting here, using iq's classic hex-tiling trick
//    (two interleaved rectangular grids, pick whichever cell center is
//    closer) to get a per-pixel distance to the nearest hex edge.

uniform bool use_texture = true;
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
	float r = length(centered) / hex_scale;
	float pulse_r = mod(TIME * pulse_speed, pulse_spacing);
	float pulse = exp(-pow(r - pulse_r, 2.0) / pulse_width);
	float t = clamp(r / 10.0, 0.0, 1.0);
	vec3 line_color = mix(color_a.rgb, color_b.rgb, t);

	vec3 color;
	if (use_texture) {
		vec3 base = texture(TEXTURE, UV).rgb;
		// Screen-blend the pulse glow on top of the painted art (brightens
		// toward line_color without ever darkening it) so the traveling
		// wave reads as light sweeping across the existing scene.
		color = clamp(base + line_color * pulse * pulse_strength * (1.0 - base), 0.0, 1.0);
	} else {
		vec2 grid_uv = centered / hex_scale;
		vec2 gv = hex_center_offset(grid_uv);
		float d = hex_edge_dist(gv);
		float edge = 1.0 - clamp(abs(d - 0.5) / 0.04, 0.0, 1.0);
		float glow = edge * (base_glow + pulse * pulse_strength);
		color = mix(bg_color.rgb, line_color * 1.3, clamp(glow, 0.0, 1.0));
	}
	COLOR = vec4(color, 1.0);
}
