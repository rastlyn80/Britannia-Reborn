shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform bool fire_steed = false;

const vec3 luma = vec3(.2126, .7152, .0722);

void fragment() {
	vec3 source = texture(albedo_texture, UV).rgb;
	float strength = dot(source, luma);
	float peak = max(source.r, max(source.g, source.b));
	float saturation = (peak - min(source.r, min(source.g, source.b))) / max(.001, peak);
	vec3 coat = source;
	if (use_hue && (!partial_hue || saturation < .08)) {
		float brightness = pow(clamp(peak, 0., 1.), 1. / 2.2);
		coat = texture(hue_palette, vec2((floor(brightness * 31.) + .5) / 32., .5)).rgb;
		coat *= clamp(strength * 1.65, .39, 1.15);
	}

	vec2 texel = 1. / vec2(textureSize(albedo_texture, 0));
	vec2 dx = vec2(texel.x, 0.);
	vec2 dy = vec2(0., texel.y);
	float relief_x = dot(texture(albedo_texture, UV - dx).rgb - texture(albedo_texture, UV + dx).rgb, luma);
	float relief_y = dot(texture(albedo_texture, UV + dy).rgb - texture(albedo_texture, UV - dy).rgb, luma);
	NORMAL_MAP = normalize(vec3(relief_x * .31, relief_y * .31, 1.)) * .5 + .5;

	float warm = smoothstep(.10, .50, source.r - source.b);
	float fire = warm * smoothstep(.06, .82, strength);
	float eyes = smoothstep(.12, .45, source.r - max(source.g, source.b));
	float baked_highlight = smoothstep(.09, .38, strength) * (1. - eyes);
	ALBEDO = coat * (fire_steed ? mix(.82, .55, fire) : mix(1.08, .78, baked_highlight));
	EMISSION = coat * (fire_steed ? fire * .39 : eyes * .27);
	ROUGHNESS = fire_steed ? mix(.87, .71, fire) : .83;
	METALLIC = 0.;
	SPECULAR = .26;
}
