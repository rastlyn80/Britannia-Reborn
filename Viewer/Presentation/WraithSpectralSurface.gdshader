shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;

void fragment() {
	vec4 texel = texture(source_atlas, UV);
	float red = texel.r <= 0.0031308 ? texel.r * 12.92 : 1.055 * pow(texel.r, 1.0 / 2.4) - 0.055;
	ALBEDO = vec3(0.0);
	ALPHA = texel.a * clamp(1.0 - 1.5 * red, 0.0, 1.0);
}
