// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;

const vec3 LUMA = vec3(.2126, .7152, .0722);

float grain(vec2 p) {
	float fibres = sin(p.x * 385.0 + 3.0 * sin(p.y * 93.0));
	float chips = sin(p.x * 179.0 - p.y * 149.0) * sin(p.y * 131.0);
	return fibres * .65 + chips * .35;
}

void fragment() {
	vec3 source = texture(albedo_texture, UV).rgb;
	float lum = dot(source, LUMA);
	float brightest = max(source.r, max(source.g, source.b));
	float saturation = (brightest - min(source.r, min(source.g, source.b))) / max(.001, brightest);
	vec2 step_uv = 1.0 / vec2(textureSize(albedo_texture, 0));
	float dx = dot(texture(albedo_texture, UV - vec2(step_uv.x, 0.)).rgb - texture(albedo_texture, UV + vec2(step_uv.x, 0.)).rgb, LUMA);
	float dy = dot(texture(albedo_texture, UV + vec2(0., step_uv.y)).rgb - texture(albedo_texture, UV - vec2(0., step_uv.y)).rgb, LUMA);
	float fibres = grain(UV);
	float small_ridges = grain(UV + vec2(.002, 0.)) - fibres;
	float patches = sin(UV.x * 40.0 + 1.4 * sin(UV.y * 29.0)) * sin(UV.y * 42.0);
	float moss = smoothstep(.05, .70, COLOR.r * (.79 + .23 * patches + .15 * fibres));
	float red = smoothstep(.11, .34, source.r - source.g * 1.5);
	moss *= 1.0 - .78 * red;
	vec3 bark = source * (.91 + .09 * fibres);
	vec3 leaves = vec3(.24, .44, .105) * (.32 + 1.30 * lum + .10 * fibres);
	vec3 colour = mix(bark, leaves, moss * .76);
	if (use_hue && (!partial_hue || saturation < .08)) {
		float value = pow(clamp(brightest, 0., 1.), 1.0 / 2.2);
		colour = texture(hue_palette, vec2((floor(value * 31.) + .5) / 32., .5)).rgb * clamp(lum * 2., .4, 1.3);
	}
	ALBEDO = colour;
	NORMAL_MAP = normalize(vec3(dx * .78 + small_ridges * .12, dy * .63, 1.)) * .5 + .5;
	ROUGHNESS = mix(.91, .81, moss);
	SPECULAR = .19;
}
