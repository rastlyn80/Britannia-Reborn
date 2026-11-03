shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float phase = 0.0;
uniform float twist = 0.0;
uniform sampler2D hue_palette : source_color, filter_linear, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;

void fragment() {
	float height = UV.y;
	float angle = UV.x * TAU;
	float warp = 0.68 * sin(angle * 4.0 - height * 7.0 + phase + twist)
		+ 0.35 * sin(angle * 9.0 + height * 15.0);
	float spiral = sin(3.0 * angle + height * 23.0 - phase * 2.0 + twist + warp);
	float secondary = sin(5.0 * angle + height * 35.0 - phase * 3.0);
	float ribbon = pow(max(0.0, spiral), 8.0) + 0.24 * pow(max(0.0, secondary), 4.0);
	float edge = smoothstep(0.0, 0.18, height) * (1.0 - smoothstep(0.72, 1.0, height));
	float pulse = 0.4 + 0.6 * smoothstep(-0.8, 0.8, sin(angle * 3.0 - height * 12.0 + phase + twist));
	vec3 colour = vec3(0.27, 0.56, 1.0);
	if (use_hue && (!partial_hue || twist < 2.0)) {
		colour = texture(hue_palette, vec2(clamp(ribbon, 0.18, 0.95), 0.5)).rgb;
	}
	ALBEDO = mix(colour, vec3(0.88, 0.95, 1.0), pow(ribbon * 0.8, 2.0));
	ALPHA = ribbon * edge * pulse * 0.62;
}
