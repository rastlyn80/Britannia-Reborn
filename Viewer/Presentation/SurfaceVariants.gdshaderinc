// Multi-variant surface sampling (see SurfaceVariants.gd). Requires
// SurfaceNoise.gdshaderinc. cell_size in metres; uv in metres.
// The variant of a cell is (x + 2y + block offset) mod count: horizontal,
// vertical and diagonal neighbours always differ. Corner weights blend the
// four nearest cells over the middle 60% of each cell, and every variant is
// pulled toward the first (reference) variant's mean colour.
void variant_sample(sampler2DArray albedo_map, sampler2DArray normal_map, float scales[6], vec3 means[6], int count, vec2 uv, float cell_size, out vec3 albedo, out vec3 normal) {
	vec2 g = uv/cell_size-0.5;
	vec2 base = floor(g);
	vec2 t = smoothstep(0.2,0.8,fract(g));
	albedo = vec3(0.0);
	normal = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 corner = base+vec2(float(i%2),float(i/2));
		float w = (i%2 == 1 ? t.x : 1.0-t.x)*(i/2 == 1 ? t.y : 1.0-t.y);
		if (w < 0.001) continue;
		float block = floor(surface_hash(floor(corner/5.0))*float(count));
		int k = int(mod(corner.x+2.0*corner.y+block,float(count)));
		// A random offset per cell keeps the same variant from lining up.
		vec2 shift = vec2(surface_hash(corner),surface_hash(corner+31.0))*7.0;
		vec3 coords = vec3(uv*scales[k]+shift,float(k));
		vec3 c = texture(albedo_map,coords).rgb;
		c *= mix(vec3(1.0),means[0]/max(means[k],vec3(0.02)),0.7);
		albedo += c*w;
		normal += texture(normal_map,coords).rgb*w;
		total += w;
	}
	albedo /= max(total,0.0001);
	normal /= max(total,0.0001);
}
