shader_type spatial;
uniform vec2 source_origin=vec2(0.0);
render_mode cull_disabled;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
uniform vec4 palette : source_color=vec4(0.6,0.5,0.4,1.0);
uniform bool wood=false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+vec3(source_origin.x,0.0,source_origin.y);}
void fragment(){
 vec3 n=abs((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec2 uv=n.x>n.z?world_position.zy:world_position.xy;
 if(n.y>max(n.x,n.z))uv=world_position.xz;
 vec3 surface=texture(surface_albedo,uv*surface_scale).rgb;
 float detail=dot(surface,vec3(0.2126,0.7152,0.0722));
 float broad=surface_fbm(uv*0.55);
 ALBEDO=wood?mix(palette.rgb,surface*palette.rgb*2.3,0.50):palette.rgb*mix(0.90,1.06,detail)*mix(0.94,1.02,broad);
 ROUGHNESS=clamp(texture(surface_roughness,uv*surface_scale).r,0.60,0.96);
 NORMAL_MAP=texture(surface_normal_map,uv*surface_scale).rgb;
 NORMAL_MAP_DEPTH=0.35;
 SPECULAR=0.25;
}
