shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color=vec4(0.12,0.18,0.32,1.0);
void fragment(){
	vec2 cell=fract(UV*3.0)-0.5;
	float diamond=abs(cell.x)+abs(cell.y);
	float ornament=1.0-smoothstep(0.28,0.36,diamond);
	float weave=0.96+0.04*sin(UV.x*500.0)*sin(UV.y*500.0);
	ALBEDO=mix(base_color.rgb,vec3(0.61,0.43,0.13),ornament*0.7)*weave;
	ROUGHNESS=1.0;
}
