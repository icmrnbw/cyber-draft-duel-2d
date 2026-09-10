shader_type canvas_item;

// Animated ground fire patch (Demolitionist's Firestorm Lv2+ ability,
// 2026-09-11) -- procedural, no art asset, same "shape built in code"
// approach as the rest of this project's cheap VFX (energy_line, the
// arena floor's pulse). A soft circular falloff for the puddle shape, a
// layered sine-based flicker (no true noise texture needed at this scale)
// for the flame's restless intensity, and a dark-red-to-bright-yellow
// color ramp driven by that same flicker so hotter-looking flickers also
// read as brighter/more saturated, like real fire.

uniform float intensity : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 centered = (UV - 0.5) * 2.0;
	float dist = length(centered);

	float flicker = 0.75
		+ 0.15 * sin(TIME * 9.0 + UV.x * 14.0)
		+ 0.15 * sin(TIME * 6.3 + UV.y * 11.0 + 1.7)
		+ 0.1 * sin(TIME * 13.0 + dist * 20.0);
	flicker = clamp(flicker, 0.3, 1.3);

	float shape = 1.0 - smoothstep(0.35, 1.0, dist);
	shape *= flicker;

	vec3 cold = vec3(0.55, 0.05, 0.02);
	vec3 hot = vec3(1.0, 0.75, 0.15);
	vec3 color = mix(cold, hot, clamp(flicker - 0.3, 0.0, 1.0));

	COLOR = vec4(color, clamp(shape * intensity, 0.0, 1.0));
}
