shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase : hint_range(0.0, 1.0);
uniform bool ground_plane = false;

void vertex() {
	if (!ground_plane) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(INV_VIEW_MATRIX[0].xyz), 0.0),
			vec4(normalize(INV_VIEW_MATRIX[1].xyz), 0.0),
			vec4(normalize(INV_VIEW_MATRIX[2].xyz), 0.0),
			MODEL_MATRIX[3]
		);
	}
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float expansion = mix(0.075, 0.94, smoothstep(0.04, 0.38, phase));
	expansion *= 1.0 - 0.63 * smoothstep(0.66, 1.0, phase);
	float diamond = abs(p.x) + abs(p.y) * (ground_plane ? 1.0 : 1.25);
	float boundary = diamond / max(expansion, 0.01);
	float core = (1.0 - smoothstep(0.54, 0.75, boundary)) * (ground_plane ? 0.66 : 0.16);
	float edge = (1.0 - smoothstep(0.025, 0.105, abs(boundary - 0.82))) * 0.24;
	float fringe = (1.0 - smoothstep(0.025, 0.090, abs(boundary - 0.98))) * 0.14;
	float star = (1.0 - smoothstep(0.003, 0.037, min(abs(p.x), abs(p.y)))) *
		(1.0 - smoothstep(0.04, 0.25, max(abs(p.x), abs(p.y)))) * (1.0 - smoothstep(0.12, 0.29, phase));
	float envelope = smoothstep(0.01, 0.12, phase) * (1.0 - smoothstep(0.60, 0.99, phase));
	ALBEDO = mix(vec3(0.32, 0.42, 0.50), vec3(0.82, 0.86, 0.89), clamp(core + star, 0.0, 1.0));
	ALPHA = min(0.85, (core + edge + fringe) * envelope + star * 0.84);
}

