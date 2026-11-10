// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;

uniform vec4 dark_tint : source_color = vec4(0.64, 0.05, 0.01, 1.0);
uniform vec4 bright_tint : source_color = vec4(1.0, 0.65, 0.10, 1.0);
uniform sampler2D hue_palette : source_color, filter_nearest, repeat_disable;
uniform bool use_hue = false;
uniform float phase = 0.0;
uniform float offset = 0.0;
uniform float density = 0.78;
varying vec3 sphere_point;

float hash_cell(vec3 cell) {
	return fract(sin(dot(cell, vec3(127.1, 311.7, 267.5))) * 43758.5453);
}

float noise_cell(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float near_a = mix(hash_cell(i), hash_cell(i + vec3(1, 0, 0)), f.x);
	float near_b = mix(hash_cell(i + vec3(0, 1, 0)), hash_cell(i + vec3(1, 1, 0)), f.x);
	float far_a = mix(hash_cell(i + vec3(0, 0, 1)), hash_cell(i + vec3(1, 0, 1)), f.x);
	float far_b = mix(hash_cell(i + vec3(0, 1, 1)), hash_cell(i + vec3(1, 1, 1)), f.x);
	return mix(mix(near_a, near_b, f.y), mix(far_a, far_b, f.y), f.z);
}

void vertex() {
	sphere_point = VERTEX;
	float turbulence = noise_cell(VERTEX * 5.0 + vec3(offset, -phase, 0));
	VERTEX += NORMAL * (turbulence - 0.43) * 0.24;
	VERTEX.y += 0.16 * turbulence * max(0.0, VERTEX.y);
}

void fragment() {
	vec3 p = sphere_point * vec3(5.2, 3.2, 5.0) + vec3(offset, -phase, 0);
	p.xz += vec2(noise_cell(p + vec3(1, 3, 0)), noise_cell(p + vec3(4, 1, 0))) * 1.2;
	float n = 0.56 * noise_cell(p) + 0.29 * noise_cell(p * 2.4) + 0.15 * noise_cell(p * 5.1);
	float facing = max(0.0, dot(normalize(NORMAL), normalize(VIEW)));
	float heat = smoothstep(0.28, 0.84, n + 0.21 * facing);
	vec3 flame = mix(dark_tint.rgb, bright_tint.rgb, heat);
	if (use_hue) {
		float sample_id = floor(pow(0.12 + 0.88 * heat, 1.0 / 2.2) * 31.0);
		flame = texture(hue_palette, vec2((sample_id + 0.5) / 32.0, 0.5)).rgb;
	}
	ALBEDO = flame;
	EMISSION = flame * (0.27 + 0.73 * heat);
	float edge = smoothstep(0.09, 0.79, facing);
	ALPHA = density * smoothstep(0.20, 0.76, n + 0.14 * facing) * edge;
}
