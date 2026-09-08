shader_type canvas_item;

// Team identity as a rim-light glow around the whole silhouette, rather than
// recoloring scattered bright pixels (the old luminance-threshold "trim"
// approach -- it picked up a visor slit here, a stray circuit-line dot
// there, which read as random rather than deliberate once units started
// having their own distinct base colors). A halo around the character is
// unmistakable at a glance and needs zero art changes: computed purely from
// the sprite's own alpha silhouette, so it works on any unit's art as-is.

uniform vec3 team_color : source_color = vec3(0.15, 0.75, 1.0);
// In texels of the source texture (not screen pixels) -- since every unit's
// art shares the same canvas resolution and gets scaled by the same
// per-round unit scale, a fixed texel width stays proportionally consistent
// across the whole roster and across roster-size-driven scale changes.
uniform float rim_width : hint_range(0.0, 12.0) = 6.5;
uniform float rim_strength : hint_range(0.0, 2.0) = 1.5;
// Hit-flash: set to 1.0 on damage, tween back to 0.0.
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

// Vibrance boost (2026-09-06): the source art was generated with deliberately
// muted/desaturated colors (a "tactical grimdark" choice), which read as
// "dirt-like and boring" next to something like Draft Showdown's bright
// palette. Rather than regenerating every spritesheet (real Meshy budget +
// a lot of time), this recolors the EXISTING art at draw time -- push away
// from grayscale (saturation_boost) and lift shadows with a gamma <1
// (gamma_lift). Verified against Enforcer/Trooper/Field Medic/Marksman via
// a real before/after render (not just eyeballing the formula) before these
// defaults were picked; 1.0/1.0 is a no-op if a unit ever needs to opt out.
uniform float saturation_boost : hint_range(0.5, 3.0) = 2.2;
uniform float gamma_lift : hint_range(0.4, 1.0) = 0.72;

vec3 boost_vibrance(vec3 color) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 saturated = mix(vec3(luma), color, saturation_boost);
	return pow(clamp(saturated, 0.0, 1.0), vec3(gamma_lift));
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 final_rgb = boost_vibrance(tex.rgb);
	float final_a = tex.a;

	// Only relevant just outside the sprite's own silhouette: sample a ring
	// of texels around this one and see how much of the sprite is nearby. A
	// pixel deep inside empty space has ~0 coverage (no glow); a pixel right
	// at the edge has partial coverage (soft glow); deep inside the sprite
	// itself this whole branch is skipped, leaving the character's own art
	// untouched.
	if (tex.a < 0.5) {
		float coverage = 0.0;
		const int SAMPLES = 12;
		for (int i = 0; i < SAMPLES; i++) {
			float angle = float(i) / float(SAMPLES) * TAU;
			vec2 offset = vec2(cos(angle), sin(angle)) * rim_width * TEXTURE_PIXEL_SIZE;
			coverage += texture(TEXTURE, UV + offset).a;
		}
		coverage /= float(SAMPLES);
		float rim = smoothstep(0.02, 0.4, coverage) * rim_strength;
		final_rgb = team_color * 1.25;
		final_a = max(tex.a, clamp(rim, 0.0, 1.0));
	}

	final_rgb = mix(final_rgb, vec3(1.0), flash_amount);
	COLOR = vec4(final_rgb, final_a);
}
