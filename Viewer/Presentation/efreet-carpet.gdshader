// SPDX-License-Identifier: GPL-3.0-or-later
shader_type spatial;
render_mode cull_disabled;

uniform float wave_phase = 0.0;
uniform float roll = 0.0;

void vertex() {
	vec2 p = UV - 0.5;
	float free_edge = smoothstep(0.12, 0.50, abs(p.x));
	VERTEX.y += 0.026 * free_edge * sin(10.0 * p.x - wave_phase);
	float curled_edge = max(0.0, p.y - mix(0.5, -0.34, roll));
	VERTEX.y += curled_edge * curled_edge * (0.45 + 0.32 * roll);
	VERTEX.z -= roll * (p.y + 0.5) * 0.61;
}

void fragment() {
	vec2 p = abs(UV - 0.5);
	float edge = min(0.5 - p.x, 0.5 - p.y);
	float gold_lines = 1.0 - smoothstep(0.004, 0.008, abs(edge - 0.026));
	gold_lines = max(gold_lines, 1.0 - smoothstep(0.003, 0.006, abs(edge - 0.094)));
	float border = smoothstep(0.035, 0.043, edge) * (1.0 - smoothstep(0.079, 0.089, edge));
	vec2 tile = abs(fract(UV * vec2(13.0, 9.0)) - 0.5);
	float diamonds = 1.0 - smoothstep(0.26, 0.31, tile.x + tile.y);
	float medallion = 1.0 - smoothstep(0.31, 0.34, p.x + 1.26 * p.y);
	float inner_trim = 1.0 - smoothstep(0.004, 0.010, abs(p.x + 1.26 * p.y - 0.32));
	float pattern = max(gold_lines, max(border * diamonds, inner_trim));
	float threads = sin(UV.x * 840.0) * sin(UV.y * 670.0);
	vec3 wool = mix(vec3(0.28, 0.029, 0.035), vec3(0.43, 0.061, 0.051), medallion);
	wool = mix(wool, vec3(0.68, 0.39, 0.11), pattern * 0.90);
	ALBEDO = wool * (1.0 + threads * 0.061);
	ROUGHNESS = 0.87;
}
