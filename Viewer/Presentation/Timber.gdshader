shader_type spatial;
uniform vec2 source_origin=vec2(0.0);
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform vec4 tint : source_color = vec4(0.45,0.30,0.18,1.0);
varying vec3 position_in_world;
void vertex(){position_in_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+vec3(source_origin.x,0.0,source_origin.y);}
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
void fragment(){
 vec3 p=position_in_world;
 float grain=surface_fbm(vec2(p.x*24.0+p.y*7.0,p.z*0.65));
 float line=sin(p.x*95.0+surface_noise(p.xz*1.8)*8.0+p.y*14.0);
 float pores=surface_noise(p.xz*60.0);
 vec3 wood=texture(surface_albedo,p.xz*surface_scale).rgb;
 ALBEDO=mix(tint.rgb*mix(0.86,1.08,grain),wood*tint.rgb*2.6,0.55);
 ROUGHNESS=mix(0.64+grain*0.14,texture(surface_roughness,p.xz*surface_scale).r,0.55);
 SPECULAR=0.3;
 NORMAL_MAP=texture(surface_normal_map,p.xz*surface_scale).rgb;
 NORMAL_MAP_DEPTH=0.3;
}
