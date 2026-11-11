// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;

uniform float phase = 0.0;
uniform bool core = false;
uniform float density = 1.0;
uniform sampler2D hue_palette : source_color, filter_linear, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform float action_gain : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float pulse = 0.85 + 0.15 * sin(phase * 3.0 + UV.x * 18.0 + UV.y * 7.0);
	float pattern = sin(UV.x * 37.7 + UV.y * 13.0 - phase * 2.0);
	float ridge = 0.72 + 0.28 * pattern * pattern;
	float coverage = core ? pow(face, 0.8) : pow(max(0.0, 1.0 - UV.y), 1.3) * pow(face, 1.2) * pulse * ridge;
	vec3 energy = vec3(0.30, 0.092, 0.59);
	if (use_hue && (!partial_hue || !core)) {
		energy = texture(hue_palette, vec2(0.65 + 0.25 * UV.y, 0.5)).rgb;
	}
	float rim = core ? pow(1.0 - face, 1.35) : 0.52 + 0.48 * UV.y;
	float kernel = core ? pow(face, 2.2) : 0.0;
	float flare = kernel * (0.22 + 0.46 * action_gain) + rim * (0.33 + 0.46 * action_gain);
	vec3 sparks = mix(energy, vec3(0.72, 0.64, 0.91), 0.32 * action_gain * kernel);
	ALBEDO = mix(vec3(0.009, 0.006, 0.022), sparks, clamp(flare, 0.0, 1.0));
	EMISSION = sparks * (rim * 0.5 + action_gain * coverage * 0.58);
	ALPHA = coverage * density * (core ? 0.97 : 0.76);
}
