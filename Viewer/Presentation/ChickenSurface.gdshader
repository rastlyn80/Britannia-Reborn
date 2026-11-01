shader_type spatial;
uniform vec4 source_colour : source_color=vec4(1.);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_texture=false;
uniform bool use_normal=false;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool partial_region=false;
uniform float normal_strength=.6;
uniform float source_roughness=.85;
void fragment(){
 vec3 colour=source_colour.rgb*(use_texture ? texture(albedo_texture,UV).rgb : vec3(1.));
 if(use_hue && (!partial_hue || partial_region)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb;
 }
 ALBEDO=colour;
 if(use_normal){NORMAL_MAP=texture(normal_texture,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
 ROUGHNESS=clamp(source_roughness,.65,.95);SPECULAR=.25;METALLIC=0.;
}
