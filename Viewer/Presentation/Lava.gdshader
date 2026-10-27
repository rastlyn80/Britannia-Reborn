shader_type spatial;
// Molten surface: slow world-space crust plates over a glowing core. "acid"
// tint gives the green dungeon acid/slime pools the same flowing treatment.
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform vec2 source_origin=vec2(0.0);
uniform vec3 hot : source_color=vec3(1.0,0.42,0.08);
uniform vec3 crust : source_color=vec3(0.16,0.07,0.05);
uniform float glow=3.2;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+vec3(source_origin.x,0.0,source_origin.y);}
void fragment(){
 vec2 uv=world_position.xz;
 vec2 flow=vec2(TIME*0.035,TIME*0.02);
 float plates=surface_fbm(uv*0.9+flow);
 float cracks=smoothstep(0.38,0.62,surface_fbm(uv*2.3-flow*1.7+vec2(4.0,9.0)));
 float heat=clamp(1.0-smoothstep(0.42,0.6,plates)+cracks*0.45,0.0,1.0);
 float pulse=0.85+0.15*sin(TIME*0.9+surface_noise(uv*0.5)*6.0);
 ALBEDO=mix(crust,hot*0.6,heat);
 EMISSION=hot*heat*heat*glow*pulse;
 ROUGHNESS=mix(0.95,0.55,heat);
 SPECULAR=0.2;
}
