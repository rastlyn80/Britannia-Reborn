// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;

void fragment() {
	vec3 chitin = texture(albedo_texture, UV).rgb;
	float intensity = max(chitin.r, max(chitin.g, chitin.b));
	float saturation = (intensity - min(chitin.r, min(chitin.g, chitin.b))) / max(0.001, intensity);
	float shell_marking = smoothstep(0.06, 0.23, chitin.b - max(chitin.r, chitin.g)) * smoothstep(0.09, 0.32, chitin.b);
	vec3 warm_marking = vec3(1.0, 0.105, 0.018) * min(1.0, 0.28 + intensity * 1.3);
	vec3 colour = mix(chitin, warm_marking, shell_marking);
	if (use_hue && (!partial_hue || saturation < 0.08)) {
		float value = floor(pow(clamp(intensity, 0.0, 1.0), 1.0 / 2.2) * 31.0);
		float brightness = dot(chitin, vec3(0.2126, 0.7152, 0.0722));
		colour = texture(hue_palette, vec2((value + 0.5) / 32.0, 0.5)).rgb * clamp(brightness * 2.0, 0.4, 1.3);
	}
	ALBEDO = colour;
	ROUGHNESS = mix(0.70, 0.44, shell_marking);
	SPECULAR = 0.32;
	EMISSION = colour * shell_marking * 0.34;
}
