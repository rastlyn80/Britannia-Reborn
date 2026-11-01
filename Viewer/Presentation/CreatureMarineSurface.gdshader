shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform vec4 albedo_colour : source_color=vec4(1.);
uniform vec4 roughness_channel=vec4(0.,1.,0.,0.);
uniform float roughness_value=.4;
uniform float normal_strength=1.;
uniform float wetness=.7;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform bool has_roughness=false;
uniform bool use_hue=false;
uniform bool partial_hue=false;
void fragment(){
 vec4 source=(has_albedo ? texture(albedo_texture,UV) : vec4(1.))*albedo_colour;
 vec3 colour=source.rgb;
 float lightness=dot(colour,vec3(.2126,.7152,.0722));
 float saturation=(max(colour.r,max(colour.g,colour.b))-min(colour.r,min(colour.g,colour.b)))/max(.001,max(colour.r,max(colour.g,colour.b)));
 if(use_hue && (!partial_hue || saturation<.08)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(lightness*2.,.4,1.3);
 }
 ALBEDO=colour;
 if(has_normal){NORMAL_MAP=texture(normal_texture,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
 float roughness=roughness_value*(has_roughness ? dot(texture(roughness_texture,UV),roughness_channel) : 1.);
 ROUGHNESS=clamp(mix(roughness+.2,roughness,wetness),.18,.9);
 METALLIC=0.;SPECULAR=mix(.25,.5,wetness);
}
