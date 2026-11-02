shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
uniform float detail_strength=.24;
void fragment(){
 vec4 original=texture(source_atlas,UV);vec3 colour=texture(albedo_texture,UV).rgb;
 float brightness=dot(colour,vec3(.2126,.7152,.0722));
 // Partial hues classify the original atlas, independently of generated detail.
 float high=max(original.r,max(original.g,original.b));float low=min(original.r,min(original.g,original.b));
 bool neutral=(high-low)<.10;
 if(use_hue && (!partial_hue || neutral)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(brightness*1.6,.3,1.1);
 }
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(texture(albedo_texture,UV-vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float right=dot(texture(albedo_texture,UV+vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float up=dot(texture(albedo_texture,UV-vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 float down=dot(texture(albedo_texture,UV+vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour*.85;ROUGHNESS=.56;METALLIC=0.;SPECULAR=.36;
 ALPHA=use_source_alpha ? original.a : 1.;ALPHA_SCISSOR_THRESHOLD=.12;
}
