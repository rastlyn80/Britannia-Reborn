shader_type spatial;
uniform vec2 source_origin=vec2(0.0);
render_mode cull_disabled;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform vec4 roof_color : source_color=vec4(0.3,0.34,0.4,1.0);
uniform sampler2D kit_texture : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform bool wood=false;
uniform bool thatch=false;
uniform vec4 ceiling_color : source_color=vec4(0.57,0.45,0.33,1.0);
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
void fragment(){
 vec2 tile=UV*vec2(3.6,5.0);
 tile.x+=mod(floor(tile.y),2.0)*0.5;
 vec2 f=fract(tile);
 vec2 edge=min(f,1.0-f);
 float aa=length(fwidth(tile));
 float joint=smoothstep(0.008,0.035+aa,min(edge.x,edge.y));
 float variation=mix(0.91,1.08,surface_hash(floor(tile)));
 float micro=surface_noise(UV*32.0);
 vec3 surface=texture(surface_albedo,UV*surface_scale).rgb;
 float luminosity=dot(surface,vec3(0.2126,0.7152,0.0722));
 ALBEDO=roof_color.rgb*mix(0.78,1.18,clamp(luminosity*3.0,0.0,1.0));
 NORMAL_MAP=texture(surface_normal_map,UV*surface_scale).rgb;
 NORMAL_MAP_DEPTH=0.6;
 ROUGHNESS=clamp(texture(surface_roughness,UV*surface_scale).r,0.55,0.95);
 AO=1.0;
 if(thatch){
  float straw=surface_noise(UV*vec2(95.0,2.5));
  float bundles=smoothstep(0.04,0.15,fract(UV.y*4.0));
  ALBEDO=roof_color.rgb*mix(0.65,1.18,straw)*mix(0.78,1.0,bundles);
  NORMAL_MAP=normalize(vec3((straw-0.5)*0.25,0.08,1.0))*0.5+0.5;
  ROUGHNESS=0.96;
 }
 if(!FRONT_FACING){
  float board=fract(UV.x*4.0);
  float seam=smoothstep(0.004,0.02+fwidth(UV.x)*4.0,min(board,1.0-board));
  float grain=surface_fbm(UV*vec2(25.0,0.6));
  ALBEDO=ceiling_color.rgb*mix(0.85,1.03,grain)*mix(0.82,1.0,seam);
  NORMAL_MAP=vec3(0.5,0.5,1.0);
  AO=1.0;
  ROUGHNESS=0.88;
 }
 SPECULAR=0.26;
}
