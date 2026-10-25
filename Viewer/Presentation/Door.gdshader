shader_type spatial;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
uniform float leaf_width=0.94;
varying vec3 local_position;
varying vec3 local_normal;
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
 vec2 uv=abs(local_normal.z)>0.5?local_position.xy:local_position.zy;
 vec2 grain_uv=vec2(uv.x*0.85,uv.y*0.45)*surface_scale;
 vec3 timber=texture(surface_albedo,grain_uv).rgb;
 float plank=fract((local_position.x/leaf_width+0.5)*5.0);
 float joint=1.0-smoothstep(0.008,0.028,min(plank,1.0-plank));
 float grain=surface_fbm(uv*vec2(18.0,0.7));
 ALBEDO=timber*vec3(0.90,0.73,0.53)*mix(0.91,1.08,grain)*(1.0-joint*0.45);
 ROUGHNESS=max(0.66,texture(surface_roughness,grain_uv).r);
 NORMAL_MAP=texture(surface_normal_map,grain_uv).rgb;
 NORMAL_MAP_DEPTH=0.22;
 SPECULAR=0.22;
}
