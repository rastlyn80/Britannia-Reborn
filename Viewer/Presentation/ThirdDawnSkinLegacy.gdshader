shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 base = texture(albedo_texture, UV).rgb;
	// Linen is the lower-right atlas band. This preserves the source briefs;
	// the experiment changes surface treatment, not anatomical geometry.
	float linen = step(0.755, UV.y) * step(0.25, UV.x);
	float pores = grain(floor(UV * 1500.0));
	ALBEDO = base;
	METALLIC = 0.0;
	ROUGHNESS = mix(0.62 + (pores - 0.5) * 0.06, 0.93, linen);
	SPECULAR = mix(0.27, 0.12, linen);
	NORMAL_MAP = normalize(vec3((pores - 0.5) * 0.035,
		(grain(floor(UV * 1500.0) + vec2(1.0, 0.0)) - 0.5) * 0.035, 1.0)) * 0.5 + 0.5;
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	SSS_STRENGTH = (1.0 - linen) * 0.07;
#endif
}
