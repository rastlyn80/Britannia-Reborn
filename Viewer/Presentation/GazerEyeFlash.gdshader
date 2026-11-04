shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float radius = length(UV - vec2(0.5)) * 2.0;
	float halo = 1.0 - smoothstep(0.0, 1.0, radius);
	float core = 1.0 - smoothstep(0.0, 0.32, radius);
	ALBEDO = tint.rgb * (1.0 + core);
	ALPHA = strength * (0.42 * halo * halo + 0.58 * core);
}
