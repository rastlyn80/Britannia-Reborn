shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform vec4 mineral_colour : source_color=vec4(.5,.5,.5,1.);
uniform float metallic_strength=0.;
uniform vec2 roughness_range=vec2(.76,.98);
uniform float normal_strength=.55;
uniform float uv_scale=1.;
void fragment(){
 vec2 uv=UV*uv_scale;
 vec3 source=texture(albedo_texture,uv).rgb;
 float lightness=dot(source,vec3(.2126,.7152,.0722));
 vec3 colour=mineral_colour.rgb*clamp(lightness*3.,.25,1.65);
 float saturation=(max(colour.r,max(colour.g,colour.b))-min(colour.r,min(colour.g,colour.b)))/max(.001,max(colour.r,max(colour.g,colour.b)));
 if(use_hue && (!partial_hue || saturation<.08)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(lightness*2.,.4,1.3);
 }
 ALBEDO=colour;
 NORMAL_MAP=texture(normal_texture,uv).rgb;NORMAL_MAP_DEPTH=normal_strength;
 float roughness=texture(roughness_texture,uv).r;
 ROUGHNESS=mix(roughness_range.x,roughness_range.y,roughness);
 // Oxide/rough inclusions remain diffuse; exposed smoother regions reflect.
 METALLIC=metallic_strength*(1.-smoothstep(.68,.96,roughness)*.8);
 SPECULAR=.45;
}
