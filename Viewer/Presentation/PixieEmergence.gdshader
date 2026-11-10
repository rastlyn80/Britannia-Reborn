// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float diameter = 1.0;
uniform float strength = 0.0;

void vertex() {
	vec4 view_center = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	POSITION = PROJECTION_MATRIX * (view_center + vec4(VERTEX.xy * diameter, 0.0, 0.0));
}

void fragment() {
	float distance_from_center = length(UV - vec2(0.5)) * 2.0;
	float halo = 1.0 - smoothstep(0.18, 1.0, distance_from_center);
	float core = exp(-28.0 * distance_from_center * distance_from_center);
	ALBEDO = mix(vec3(0.89, 0.54, 0.26), vec3(1.0, 0.94, 0.73), core);
	ALPHA = strength * (0.19 * halo * halo + 0.7 * core);
}
