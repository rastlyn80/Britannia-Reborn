shader_type spatial;
uniform vec2 source_origin=vec2(0.0);
render_mode cull_disabled;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 palette : source_color;
uniform bool wood=false;
uniform bool masonry=false;
uniform bool double_sided=false;
uniform bool open_caps=false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+vec3(source_origin.x,0.0,source_origin.y);}
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
void fragment(){
 if(!double_sided && !FRONT_FACING){discard;}
 vec3 n=abs((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 if(open_caps && n.y>0.99){discard;}
 vec2 uv=n.x>n.z?world_position.zy:world_position.xy;
 if(n.y>max(n.x,n.z))uv=world_position.xz;
 float broad=surface_fbm(uv*0.7);
 float fine=surface_noise(uv*30.0);
 vec3 source=texture(surface_albedo,uv*surface_scale).rgb;
 float detail=dot(source,vec3(0.2126,0.7152,0.0722));
 if(wood){
  float grain=surface_fbm(uv*vec2(20.0,0.6));
  float line=sin(uv.x*90.0+surface_noise(uv*2.0)*5.0);
  ALBEDO=mix(palette.rgb*mix(0.82,1.08,grain),source*palette.rgb*2.3,0.50);
  ROUGHNESS=0.76+grain*0.10;
  NORMAL_MAP=texture(surface_normal_map,uv*surface_scale).rgb;
 }else{
  ALBEDO=palette.rgb*mix(0.90,1.04,broad)*mix(0.94,1.04,detail);
  if(masonry)ALBEDO=mix(palette.rgb,source*palette.rgb*1.45,0.82);
  ROUGHNESS=0.87+fine*0.08;
  NORMAL_MAP=mix(vec3(0.5,0.5,1.0),texture(surface_normal_map,uv*surface_scale).rgb,0.55);
 }
 NORMAL_MAP_DEPTH=0.35;
 ROUGHNESS=mix(ROUGHNESS,texture(surface_roughness,uv*surface_scale).r,0.5);
 SPECULAR=0.24;
}
