// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform float opening : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float fibres = 1.0 - smoothstep(0.04, 0.21, abs(sin(angle * 13.0 + radius * 0.9)));
	float rings = 1.0 - smoothstep(0.06, 0.36, abs(sin(radius * 34.0 + 0.37 * cos(angle * 13.0))));
	float tear = 0.10 + opening * 0.77 + cos(angle * 5.0 + 0.9) * 0.045;
	float web = smoothstep(tear - 0.04, tear + 0.05, radius) * (1.0 - smoothstep(0.90, 0.99, radius));
	float rim = 1.0 - smoothstep(0.015, 0.058, abs(radius - 0.91));
	float crescent = mix(1.0, 1.0 - smoothstep(-0.12, 0.52, p.y), opening);
	ALBEDO = vec3(0.79, 0.85, 0.82);
	ALPHA = (0.34 * web * max(fibres, rings * 0.74) + rim * 0.72) * crescent * (1.0 - smoothstep(0.52, 0.94, opening));
}
