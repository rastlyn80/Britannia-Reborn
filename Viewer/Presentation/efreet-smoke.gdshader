// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

instance uniform float density = 0.0;
instance uniform float drift = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float folds = sin(7.5 * p.x + 3.0 * p.y + 5.0 * drift) *
		sin(3.4 * p.x - 6.8 * p.y - 4.0 * drift);
	float rim = smoothstep(0.15, 1.0, length(p) + 0.15 * folds);
	ALBEDO = mix(vec3(0.24, 0.24, 0.40), vec3(0.56, 0.58, 0.75), 0.5 + 0.36 * folds);
	ALPHA = density * (1.0 - rim) * (0.65 + 0.28 * folds);
}
