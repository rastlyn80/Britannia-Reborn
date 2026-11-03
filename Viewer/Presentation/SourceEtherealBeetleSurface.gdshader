shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;

void fragment() {
	vec4 source = texture(atlas, UV);
	vec3 colour = source.rgb;
	float brightest = max(colour.r, max(colour.g, colour.b));
	float darkest = min(colour.r, min(colour.g, colour.b));
	float saturation = (brightest - darkest) / max(brightest, 0.001);
	if (use_hue && (!partial_hue || saturation < 0.08)) {
		float value = pow(clamp(brightest, 0.0, 1.0), 1.0 / 2.2);
		colour = texture(hue_palette, vec2((floor(value * 31.0) + 0.5) / 32.0, 0.5)).rgb;
	}
	ALBEDO = colour * vec3(0.70, 0.87, 1.0);
	ALPHA = source.a * 0.58;
	ROUGHNESS = 0.76;
	SPECULAR = 0.28;
	EMISSION = ALBEDO * vec3(0.12, 0.25, 0.32);
}
