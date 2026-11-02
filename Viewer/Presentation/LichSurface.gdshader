shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool use_source_alpha=true;
uniform bool partial_hue=false;
uniform bool use_accent=false;
uniform vec3 accent_tint=vec3(.42,.04,.03);
uniform float albedo_gain=.72;
uniform float detail_strength=.12;
void fragment(){
 vec4 original=texture(source_atlas,UV);
 vec4 generated=texture(albedo_texture,UV);
 // Preserve source silhouette without exposing hidden RGB fringe colours
 // from the independently generated transparency outside its own islands.
 vec3 colour=mix(original.rgb,generated.rgb,smoothstep(.10,.95,generated.a));
 bool accent=original.r>.25 && original.g<original.r*.85 && original.b<original.r*.45;
 if(use_accent && accent)colour=accent_tint*max(colour.r,max(colour.g,colour.b))*1.8;
 float brightness=dot(colour,vec3(.2126,.7152,.0722));
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(texture(albedo_texture,UV-vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float right=dot(texture(albedo_texture,UV+vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float up=dot(texture(albedo_texture,UV-vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 float down=dot(texture(albedo_texture,UV+vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 // Authored cloth dye region and albedo relief; neither is a recovered _m/normal map.
 bool cloth=UV.y>.36 && UV.x<.7;
 if(use_hue && (!partial_hue || cloth)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(brightness*2.,.4,1.3);
 }
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 ALBEDO=colour*albedo_gain;ROUGHNESS=cloth ? .92 : .81;METALLIC=0.;SPECULAR=.20;
 ALPHA=use_source_alpha ? original.a : 1.;ALPHA_SCISSOR_THRESHOLD=.12;
}
