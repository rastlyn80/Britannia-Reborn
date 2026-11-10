shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D wing_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform bool membrane = false;

void fragment() {
	vec4 texel = texture(wing_atlas, UV);
	float lightness = dot(texel.rgb, vec3(.2126, .7152, .0722));
	float peak = max(texel.r, max(texel.g, texel.b));
	float saturation = (peak - min(texel.r, min(texel.g, texel.b))) / max(.001, peak);
	if (use_hue && (!partial_hue || saturation < .08)) {
		float value = pow(clamp(peak, 0.0, 1.0), 1.0 / 2.2);
		texel.rgb = texture(hue_palette, vec2((floor(value * 31.0) + .5) / 32.0, .5)).rgb
			* clamp(lightness * 2.0, .4, 1.3);
	}
	ALBEDO = texel.rgb;
	ROUGHNESS = membrane ? .44 : .58;
	SPECULAR = membrane ? .32 : .25;
	ALPHA = texel.a;
}
