shader_type spatial;
// Falling water sheet: streaks scroll downward over a blue-green body with
// white aeration that thickens toward the foot of the fall.
#include "res://Presentation/SurfaceNoise.gdshaderinc"
render_mode cull_disabled;
uniform vec3 body : source_color=vec3(0.16,0.36,0.46);
varying vec3 world_position;
varying float height_fraction;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 height_fraction=UV.y;
}
void fragment(){
 vec2 uv=vec2(world_position.x+world_position.z,world_position.y);
 float streak=surface_fbm(vec2(uv.x*6.0,uv.y*0.7+TIME*1.6));
 float fine=surface_noise(vec2(uv.x*22.0,uv.y*2.5+TIME*3.1));
 float foam=smoothstep(0.55,0.8,streak*0.7+fine*0.3)+smoothstep(0.6,1.0,height_fraction)*0.6;
 ALBEDO=mix(body,vec3(0.9,0.95,0.97),clamp(foam,0.0,1.0));
 ALPHA=0.82+0.18*clamp(foam,0.0,1.0);
 ROUGHNESS=0.15+0.5*clamp(foam,0.0,1.0);
 SPECULAR=0.6;
}
