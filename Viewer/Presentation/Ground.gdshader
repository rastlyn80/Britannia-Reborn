shader_type spatial;
render_mode cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec3 color = COLOR.rgb;
	float variation = mix(0.94,1.06,0.5+0.25*sin(UV.x*1.7+sin(UV.y*0.8))+0.25*sin(UV.y*2.1));
	if (UV2.x > 0.5 && UV2.x < 1.5) {
		vec2 paving = UV * 2.0;
		paving.x += mod(floor(paving.y),2.0)*0.5;
		vec2 edge = min(fract(paving),1.0-fract(paving));
		float mortar = smoothstep(0.015,0.045+length(fwidth(paving)),min(edge.x,edge.y));
		color *= mix(0.80,mix(0.95,1.05,hash(floor(paving))),mortar);
	} else if (UV2.x > 1.5 && UV2.x < 2.5) {
		float seam = smoothstep(0.015,0.045,min(fract(UV.x*4.0),1.0-fract(UV.x*4.0)));
		color *= mix(0.8,1.0,seam);
	}
	ALBEDO = color * variation;
	ROUGHNESS = 0.92;
}
