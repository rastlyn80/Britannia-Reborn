shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float phase = 0.0;
uniform float embodiment = 1.0;
uniform bool dust = false;
uniform sampler2D hue_palette : source_color, filter_nearest, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;
varying vec3 sand_position;
varying float plume;

float hash_cell(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float grain_field(vec3 p) {
	vec3 i = floor(p);
	vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
	vec3 x = vec3(1.0, 0.0, 0.0);
	vec3 y = vec3(0.0, 1.0, 0.0);
	vec3 z = vec3(0.0, 0.0, 1.0);
	float near = mix(mix(hash_cell(i), hash_cell(i + x), f.x),
		mix(hash_cell(i + y), hash_cell(i + x + y), f.x), f.y);
	float far = mix(mix(hash_cell(i + z), hash_cell(i + x + z), f.x),
		mix(hash_cell(i + y + z), hash_cell(i + x + y + z), f.x), f.y);
	return mix(near, far, f.z);
}

void vertex() {
	sand_position = VERTEX;
	plume = dust ? 0.0 : COLOR.r;
	float swirl = plume * (VERTEX.y * 5.5 + phase * 2.0);
	mat2 rotation = mat2(vec2(cos(swirl), sin(swirl)), vec2(-sin(swirl), cos(swirl)));
	VERTEX.xz = rotation * VERTEX.xz;
	NORMAL.xz = rotation * NORMAL.xz;
	float pulse = sin(VERTEX.y * 23.0 + VERTEX.x * 8.0 - phase * 3.0);
	VERTEX += NORMAL * pulse * .014 * plume;
}

void fragment() {
	if (!dust && !FRONT_FACING) {
		discard;
	}
	vec3 p = sand_position * vec3(11.0, 16.0, 11.0);
	p.y -= sin(phase) * 1.4;
	float density = .63 * grain_field(p) + .26 * grain_field(p * 2.1) + .11 * grain_field(p * 5.0);
	float glint = pow(grain_field(p * 13.0), 5.0);
	float facing = max(0.0, dot(normalize(NORMAL), normalize(VIEW)));
	float light = .46 * density + .30 * facing + .12 * glint;
	vec3 colour = mix(vec3(.29, .18, .08), vec3(.85, .69, .40), light + .10);
	if (use_hue && (!partial_hue || density > .50)) {
		colour = texture(hue_palette, vec2(clamp(.16 + light, 0.0, 1.0), .5)).rgb;
	}
	float strand = sin(sand_position.y * 23.0 - atan(sand_position.z, sand_position.x) * 3.0 - phase * 4.0 + density * 4.0);
	float edge = smoothstep(.015, .16, sand_position.y + density * .13);
	ALBEDO = colour;
	ALPHA = mix(.43 + .53 * facing, (.45 + .14 * strand) * (.46 + .54 * facing) * edge, plume)
		* (.52 + .48 * density) * embodiment;
	if (dust) {
		ALPHA = (.38 + .58 * density) * (1.0 - smoothstep(.05, .73, length(sand_position.xz)));
	}
}
