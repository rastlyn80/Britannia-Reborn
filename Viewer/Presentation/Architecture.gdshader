shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 palette : source_color = vec4(0.6,0.5,0.4,1.0);
void fragment() {
	vec3 source = texture(source_texture,UV).rgb;
	float detail = dot(source,vec3(0.2126,0.7152,0.0722));
	// Keep the publisher's grain/plaster detail without oversized high-contrast
	// marks dominating every compressed, one-UO-tile building module.
	ALBEDO = palette.rgb * mix(0.84,1.12,detail);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
}
