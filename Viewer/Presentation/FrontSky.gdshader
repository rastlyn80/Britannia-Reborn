shader_type sky;
// Night sky for the front end: deep gradient, a hashed star field that thins
// toward the horizon, and the moon as a soft disc with a wide halo in the
// direction of the scene's moonlight (LIGHT0).
uniform vec3 zenith : source_color = vec3(0.027,0.039,0.078);
uniform vec3 horizon : source_color = vec3(0.17,0.16,0.23);
uniform vec3 moon_color : source_color = vec3(1.0,0.96,0.86);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void sky() {
	float up = clamp(EYEDIR.y, -0.2, 1.0);
	vec3 color = mix(horizon, zenith, smoothstep(-0.05, 0.6, up));
	if (EYEDIR.y > 0.02) {
		vec2 grid = vec2(atan(EYEDIR.z, EYEDIR.x), asin(clamp(EYEDIR.y, -1.0, 1.0))) * 70.0;
		vec2 key = floor(grid);
		float near = 1.0 - smoothstep(0.05, 0.16, length(fract(grid) - 0.5));
		float star = step(0.93, hash(key)) * near * smoothstep(0.02, 0.35, EYEDIR.y);
		color += vec3(star) * (0.55 + 0.45 * sin(TIME * 1.7 + hash(key + 3.1) * 40.0)) * 0.9;
	}
	if (LIGHT0_ENABLED) {
		float facing = dot(normalize(EYEDIR), normalize(LIGHT0_DIRECTION));
		color += moon_color * smoothstep(0.9993, 0.9996, facing) * 1.6;
		color += moon_color * pow(max(facing, 0.0), 220.0) * 0.35;
		color += vec3(0.55, 0.62, 0.85) * pow(max(facing, 0.0), 18.0) * 0.08;
	}
	COLOR = color;
}
