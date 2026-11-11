// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float fracture(vec2 location) {
	vec2 cell = floor(location);
	vec2 local = fract(location);
	float nearest = 4.0;
	float second = 4.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 id = cell + offset;
			vec2 seed = vec2(grain(id), grain(id.yx + 17.0));
			float distance_to_seed = length(offset + seed - local);
			second = min(second, max(nearest, distance_to_seed));
			nearest = min(nearest, distance_to_seed);
		}
	}
	float edge = second - nearest;
	return 1.0 - smoothstep(0.015, 0.065 + fwidth(edge) * 0.45, edge);
}

void fragment() {
	vec4 source = texture(albedo_texture, UV);
	float lightness = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float value = max(source.r, max(source.g, source.b));
	float saturation = (value - min(source.r, min(source.g, source.b))) / max(value, 0.001);
	float hot_atlas = smoothstep(0.09, 0.37, source.r - source.b * 1.25);
	float crust_pattern = fracture(UV * vec2(31.0, 26.0));
	float hot = hot_atlas * crust_pattern * smoothstep(0.08, 0.49, lightness);
	vec3 ash = vec3(0.052, 0.047, 0.044) * (0.48 + lightness * 1.8);
	vec3 stone = mix(source.rgb * 0.65, ash, 0.45 + 0.50 * hot_atlas);
	vec3 ember = mix(vec3(0.44, 0.037, 0.003), vec3(1.0, 0.32, 0.016), lightness);
	if (use_hue && (!partial_hue || saturation < 0.08)) {
		float index = floor(pow(clamp(value, 0.0, 1.0), 1.0 / 2.2) * 31.0);
		vec3 pigment = texture(hue_palette, vec2((index + 0.5) / 32.0, 0.5)).rgb;
		stone = pigment * (0.20 + 0.60 * lightness);
		ember = pigment * 1.15;
	}
	ALBEDO = mix(stone, ember, hot);
	EMISSION = ember * hot * 0.53;
	ROUGHNESS = mix(0.86, 0.52, hot);
	SPECULAR = 0.22;
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = 0.3;
}
