shader_type spatial;
render_mode cull_disabled;
// One hue of an atlas-textured scan repainted ("recolor" in
// prop-replacements.json): pixels near from_color in chroma become to_color at
// their own brightness (yellow celandine petals drawn as white poppies).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform vec3 from_color : source_color = vec3(1.0, 0.85, 0.1);
uniform vec3 to_color : source_color = vec3(0.95, 0.94, 0.9);
uniform float reach = 0.2;

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float chroma = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	float near = 1.0 - smoothstep(reach * 0.5, reach, distance(normalize(base + 0.001), normalize(from_color + 0.001)));
	float weight = near * smoothstep(0.04, 0.12, chroma);
	float light = max(base.r, max(base.g, base.b)) / max(0.01, max(from_color.r, max(from_color.g, from_color.b)));
	ALBEDO = mix(base, clamp(to_color * light, 0.0, 1.0), weight);
	if (has_normal) NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = 0.8;
}
