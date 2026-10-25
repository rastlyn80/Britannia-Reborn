shader_type spatial;
uniform vec4 water_color : source_color = vec4(0.035,0.09,0.11,1.0);
uniform vec2 source_origin = vec2(0.0);
uniform float wave_strength = 1.0;
uniform float time_override = -1.0;
varying vec2 world_uv;
void vertex() { world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz+source_origin; }
void fragment() {
 float t = time_override >= 0.0 ? time_override : TIME;
 float a = dot(world_uv,vec2(1.7,0.8))+t*0.75;
 float b = dot(world_uv,vec2(-0.6,2.3))-t*0.55;
 float ripple=(sin(a)*0.6+sin(b)*0.4)*wave_strength;
 vec2 slope=(cos(a)*vec2(1.7,0.8)*0.6+cos(b)*vec2(-0.6,2.3)*0.4)*0.07*wave_strength;
 ALBEDO=water_color.rgb*(1.0+ripple*0.07);
 ROUGHNESS=0.22+ripple*0.03;
 SPECULAR=0.7;
 NORMAL_MAP=normalize(vec3(-slope.x,-slope.y,1.0))*0.5+0.5;
}
