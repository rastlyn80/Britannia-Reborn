shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform sampler2D partial_hue_mask : filter_linear_mipmap_anisotropic;
uniform vec4 roughness_channel=vec4(0.,1.,0.,0.);
uniform float normal_strength=.65;
uniform float roughness_gain=1.;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_partial_mask=false;
void fragment(){
 vec4 source=texture(albedo_texture,UV);
 vec3 colour=source.rgb;
 float lightness=dot(colour,vec3(.2126,.7152,.0722));
 float saturation=(max(colour.r,max(colour.g,colour.b))-min(colour.r,min(colour.g,colour.b)))/max(.001,max(colour.r,max(colour.g,colour.b)));
 bool tintable=use_partial_mask ? texture(partial_hue_mask,UV).r>.2 : saturation<.08;
 if(use_hue && (!partial_hue || tintable)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(lightness*2.,.4,1.3);
 }
 ALBEDO=colour;
 NORMAL_MAP=texture(normal_texture,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;
 ROUGHNESS=clamp(dot(texture(roughness_texture,UV),roughness_channel)*roughness_gain,.45,.95);
 SPECULAR=.3;METALLIC=0.;
 ALPHA=source.a;ALPHA_SCISSOR_THRESHOLD=.12;
}
