shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// A standing moongate: a blue oval of slowly turning light, brightest at its
// rim, fading at the edges.
uniform vec4 tint : source_color = vec4(0.30,0.55,0.95,1.0);

float noise(vec2 p) { return sin(p.x) * sin(p.y); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float swirl = 0.5 + 0.5 * noise(vec2(angle * 5.0 + TIME * 0.9, r * 9.0 - TIME * 1.6));
	float body = smoothstep(1.0, 0.55, r);
	float rim = smoothstep(0.62, 0.9, r) * smoothstep(1.0, 0.9, r);
	float core = smoothstep(0.55, 0.0, r);
	vec3 color = tint.rgb * (body * (0.35 + 0.45 * swirl) + rim * 1.4) + vec3(0.75, 0.9, 1.0) * core * 0.55;
	ALBEDO = color;
	ALPHA = clamp(body + rim, 0.0, 1.0);
}
