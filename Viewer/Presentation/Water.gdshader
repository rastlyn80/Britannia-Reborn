shader_type spatial;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform vec4 water_color : source_color = vec4(0.025,0.08,0.10,1.0);
uniform vec2 source_origin=vec2(0.0);
uniform float wave_strength=1.0;
uniform float time_override=-1.0;
uniform sampler2D shore_data : filter_linear, repeat_disable;
uniform vec4 shore_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool has_shore=false;
varying vec2 world_uv;
void vertex(){
 world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz+source_origin;
 float t=time_override>=0.0?time_override:TIME;
 VERTEX.y+=(sin(dot(world_uv,vec2(0.8,0.3))+t*0.65)*0.012+cos(dot(world_uv,vec2(-0.3,0.9))-t*0.45)*0.008)*wave_strength;
}
void fragment(){
 float t=time_override>=0.0?time_override:TIME;
 float a=dot(world_uv,vec2(1.7,0.8))+t*0.75;
 float b=dot(world_uv,vec2(-0.6,2.3))-t*0.55;
 float ripple=(sin(a)*0.6+sin(b)*0.4)*wave_strength;
 vec2 fine=vec2(surface_noise(world_uv*5.0+vec2(t*0.12,0.0)),surface_noise(world_uv*5.0-vec2(0.0,t*0.09)))-0.5;
 vec2 slope=(cos(a)*vec2(1.7,0.8)*0.6+cos(b)*vec2(-0.6,2.3)*0.4)*0.105*wave_strength+fine*0.04*wave_strength;
 vec3 color=water_color.rgb;
 float foam=0.0;
 if(has_shore){
  vec3 shore=texture(shore_data,(world_uv-shore_rect.xy)/shore_rect.zw).rgb;
  float shallow=1.0-smoothstep(0.3,2.5,shore.b);
  color=mix(color,vec3(0.095,0.18,0.16),shallow*0.7);
  float edge=1.0-smoothstep(0.3,1.4,abs(shore.r));
  float wash=sin(shore.r*7.0-t*0.8+surface_noise(world_uv*1.5)*3.0)*0.5+0.5;
  foam=edge*smoothstep(0.58,0.90,wash)*0.27;
 }
 ALBEDO=mix(color*(1.0+ripple*0.055),vec3(0.42,0.48,0.40),foam);
 ROUGHNESS=0.19+foam*0.45+ripple*0.025;
 SPECULAR=0.72;
 NORMAL_MAP=normalize(vec3(-slope.x,-slope.y,1.0))*0.5+0.5;
}
