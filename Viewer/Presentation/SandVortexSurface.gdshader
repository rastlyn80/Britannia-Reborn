shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float phase = 0.0;
uniform float twist = 0.0;
uniform sampler2D hue_palette : source_color, filter_linear, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;

void fragment() {
	float height = UV.y;
	float angle = UV.x * TAU;
	float whirl = angle * 3.0 + height * 24.0 - phase * 2.0 + twist;
	float billow = 0.5 + 0.5 * sin(whirl + 0.9 * sin(angle * 5.0 + height * 18.0));
	float grain = 0.5 + 0.5 * sin(angle * 43.0 + height * 167.0 - phase * 5.0);
	float edge = smoothstep(0.0, 0.12, height) * (1.0 - smoothstep(0.56, 1.0, height));
	vec3 colour = mix(vec3(0.38, 0.24, 0.13), vec3(0.79, 0.65, 0.43), billow);
	if (use_hue && (!partial_hue || twist < 2.0)) {
		colour = texture(hue_palette, vec2(mix(0.22, 0.85, billow), 0.5)).rgb;
	}
	ALBEDO = colour;
	ALPHA = edge * billow * mix(0.27, 0.57, grain);
}
