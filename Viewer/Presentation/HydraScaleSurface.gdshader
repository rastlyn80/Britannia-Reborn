// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.32;

float luminance(vec3 sample_colour) {
	return dot(sample_colour, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec3 source = texture(albedo_texture, UV).rgb;
	float lightness = luminance(source);
	float value = max(source.r, max(source.g, source.b));
	float saturation = (value - min(source.r, min(source.g, source.b))) / max(0.001, value);
	float weight = clamp(COLOR.a, 0.0, 1.0);
	vec3 head_colour = COLOR.rgb / max(COLOR.a, 0.001);
	vec3 scales = mix(source, head_colour * (0.22 + 0.82 * sqrt(lightness)), 0.82 * weight);
	if (use_hue && (!partial_hue || saturation < 0.08)) {
		float index = floor(pow(clamp(value, 0.0, 1.0), 1.0 / 2.2) * 31.0);
		scales = texture(hue_palette, vec2((index + 0.5) / 32.0, 0.5)).rgb
			* clamp(lightness * 2.0, 0.4, 1.3);
	}
	vec2 texel = 1.0 / vec2(textureSize(albedo_texture, 0));
	float left = luminance(texture(albedo_texture, UV - vec2(texel.x, 0.0)).rgb);
	float right = luminance(texture(albedo_texture, UV + vec2(texel.x, 0.0)).rgb);
	float up = luminance(texture(albedo_texture, UV - vec2(0.0, texel.y)).rgb);
	float down = luminance(texture(albedo_texture, UV + vec2(0.0, texel.y)).rgb);
	NORMAL_MAP = normalize(vec3((left - right) * detail_strength, (down - up) * detail_strength, 1.0)) * 0.5 + 0.5;
	ALBEDO = scales;
	ROUGHNESS = mix(0.80, 0.62, weight);
	SPECULAR = 0.28;
}
