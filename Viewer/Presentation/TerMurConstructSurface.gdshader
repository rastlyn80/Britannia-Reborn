shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform vec4 finish : source_color = vec4(1.0);
uniform float roughness = 0.76;
uniform float metalness = 0.0;

void fragment() {
	vec3 source = texture(albedo_texture, UV).rgb;
	float grain = dot(source, vec3(0.2126, 0.7152, 0.0722));
	vec2 seam = UV * vec2(227.0, 171.0);
	float wear = sin(seam.x + sin(seam.y)) * sin(seam.y * 1.73 - seam.x * 0.47);
	vec3 colour = finish.rgb * (0.56 + grain * 0.69 + wear * 0.045);
	float peak = max(colour.r, max(colour.g, colour.b));
	float saturation = (peak - min(colour.r, min(colour.g, colour.b))) / max(0.001, peak);
	if (use_hue && (!partial_hue || saturation < 0.08)) {
		float shade = pow(clamp(peak, 0.0, 1.0), 1.0 / 2.2);
		colour = texture(hue_palette, vec2((floor(shade * 31.0) + 0.5) / 32.0, 0.5)).rgb;
	}
	ALBEDO = colour;
	ROUGHNESS = clamp(roughness + wear * 0.075 + (grain - 0.5) * 0.14, 0.46, 0.96);
	METALLIC = metalness;
	SPECULAR = 0.26;
}
