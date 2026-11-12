shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;

const vec3 luma = vec3(.2126, .7152, .0722);

void fragment() {
	vec3 atlas = texture(albedo_texture, UV).rgb;
	float light = dot(atlas, luma);
	float peak = max(atlas.r, max(atlas.g, atlas.b));
	float saturation = (peak - min(atlas.r, min(atlas.g, atlas.b))) / max(.001, peak);
	vec3 base = atlas;
	if (use_hue && (!partial_hue || saturation < .08)) {
		float brightness = pow(clamp(peak, 0., 1.), 1. / 2.2);
		base = texture(hue_palette, vec2((floor(brightness * 31.) + .5) / 32., .5)).rgb;
		base *= clamp(light * 1.4, .42, 1.06);
	}

	vec2 texel = 1. / vec2(textureSize(albedo_texture, 0));
	vec2 x = vec2(texel.x, 0.);
	vec2 y = vec2(0., texel.y);
	float relief_x = dot(texture(albedo_texture, UV - x).rgb - texture(albedo_texture, UV + x).rgb, luma);
	float relief_y = dot(texture(albedo_texture, UV + y).rgb - texture(albedo_texture, UV - y).rgb, luma);
	NORMAL_MAP = normalize(vec3(relief_x * .23, relief_y * .23, 1.)) * .5 + .5;

	float eye = smoothstep(.25, .62, atlas.r - max(atlas.g, atlas.b));
	float leather = smoothstep(.035, .22, atlas.b - atlas.r);
	ALBEDO = base * mix(1.03, .78, smoothstep(.16, .68, light) * (1. - eye));
	ROUGHNESS = mix(.87, .78, leather);
	METALLIC = 0.;
	SPECULAR = .22;
	EMISSION = base * eye * .2;
}
