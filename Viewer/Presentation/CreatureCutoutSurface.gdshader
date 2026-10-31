shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_alpha_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
uniform float metallic_strength : hint_range(0.,1.)=0.;
uniform float detail_strength : hint_range(0.,1.)=.32;
void fragment(){
 vec3 colour=texture(albedo_texture,UV).rgb;
 float lightness=dot(colour,vec3(.2126,.7152,.0722));
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(texture(albedo_texture,UV-vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float right=dot(texture(albedo_texture,UV+vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float up=dot(texture(albedo_texture,UV-vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 float down=dot(texture(albedo_texture,UV+vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 float saturation=(max(colour.r,max(colour.g,colour.b))-min(colour.r,min(colour.g,colour.b)))/max(.001,max(colour.r,max(colour.g,colour.b)));
 if(use_hue && (!partial_hue || saturation<.08)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(lightness*2.,.4,1.3);
 }
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour;
 // Rigid weapon surfaces opt in; saturated wood/leather handles stay matte.
 float metal=metallic_strength*(1.-smoothstep(.08,.35,saturation));
 ROUGHNESS=mix(clamp(.78+(lightness-.5)*.10,.62,.9),.4,metal);
 METALLIC=metal;SPECULAR=.28;
 ALPHA=use_source_alpha ? texture(source_alpha_texture,UV).a : 1.;
 ALPHA_SCISSOR_THRESHOLD=.12;
}
