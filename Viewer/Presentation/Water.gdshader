shader_type spatial;
uniform vec4 water_color : source_color = vec4(0.13,0.34,0.40,1.0);
varying vec2 world_uv;
void vertex(){world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
	float ripple=sin(world_uv.x*2.0+TIME*1.1)*cos(world_uv.y*2.5-TIME*0.7);
	ALBEDO=water_color.rgb*(1.0+ripple*0.06);
	ROUGHNESS=0.24;
	SPECULAR=0.65;
	NORMAL_MAP=normalize(vec3(ripple*0.07,cos(world_uv.x*2.0+TIME)*0.04,1.0))*0.5+0.5;
}
