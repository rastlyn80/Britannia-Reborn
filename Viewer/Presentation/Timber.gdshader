shader_type spatial;
uniform vec4 tint : source_color = vec4(0.45,0.30,0.18,1.0);
varying vec3 position_in_world;
void vertex() { position_in_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float grain=sin(position_in_world.x*74.0+sin(position_in_world.z*3.0)*3.0+position_in_world.y*4.0);
 float broad=sin(position_in_world.x*13.0+position_in_world.z*1.3);
 ALBEDO=tint.rgb*(0.96+grain*0.025+broad*0.035);
 ROUGHNESS=0.74+grain*0.04;
 SPECULAR=0.28;
}
