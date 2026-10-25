shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 palette : source_color;
uniform bool wood = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 n = abs((INV_VIEW_MATRIX * vec4(NORMAL,0.0)).xyz);
	vec2 uv = n.x > n.z ? world_position.zy : world_position.xy;
	if (n.y > max(n.x,n.z)) uv = world_position.xz;
	uv *= wood ? vec2(0.7,0.35) : vec2(0.55);
	vec3 source = texture(source_texture,uv).rgb;
	float detail = dot(source,vec3(0.2126,0.7152,0.0722));
	ALBEDO = palette.rgb * mix(0.76,1.08,detail);
	NORMAL_MAP = texture(surface_normal,uv).rgb;
	NORMAL_MAP_DEPTH = wood ? 0.3 : 0.45;
	ROUGHNESS = 0.92;
	SPECULAR = 0.18;
}
