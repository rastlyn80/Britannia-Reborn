shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool gel_surface=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
uniform float detail_strength=.24;
uniform float gel_strength=1.;
float grain(vec2 point){return fract(sin(dot(point,vec2(127.1,311.7)))*43758.5453);}
float smooth_grain(vec2 point){
 vec2 cell=floor(point);vec2 part=fract(point);part=part*part*(3.-2.*part);
 return mix(mix(grain(cell),grain(cell+vec2(1.,0.)),part.x),mix(grain(cell+vec2(0.,1.)),grain(cell+vec2(1.,1.)),part.x),part.y);
}
vec3 layered_colour(vec2 uv){
 vec4 original=texture(source_atlas,uv);vec4 layer=texture(albedo_texture,uv);
 return mix(original.rgb,layer.rgb,layer.a);
}
void fragment(){
 vec4 original=texture(source_atlas,UV);vec3 colour=layered_colour(UV);
 float brightness=dot(colour,vec3(.2126,.7152,.0722));
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(layered_colour(UV-vec2(texel.x,0.)),vec3(.2126,.7152,.0722));
 float right=dot(layered_colour(UV+vec2(texel.x,0.)),vec3(.2126,.7152,.0722));
 float up=dot(layered_colour(UV-vec2(0.,texel.y)),vec3(.2126,.7152,.0722));
 float down=dot(layered_colour(UV+vec2(0.,texel.y)),vec3(.2126,.7152,.0722));
 if(gel_surface){
  float broad=smooth_grain(UV*15.);float fine=smooth_grain(UV*180.);
  vec3 gel=vec3(.095,.24,.025)*(.8+brightness*.65)+vec3(.015,.025,.005)*(broad-.5);
  colour=mix(colour,gel,gel_strength);
  left+=(fine-smooth_grain((UV+vec2(.003,0.))*180.))*.12;
  up+=(fine-smooth_grain((UV+vec2(0.,.003))*180.))*.12;
 }
 float source_max=max(original.r,max(original.g,original.b));float source_min=min(original.r,min(original.g,original.b));
 if(use_hue && (!partial_hue || source_max-source_min<.10)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(brightness*1.6,.3,1.1);
 }
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour*.85;
 ROUGHNESS=gel_surface ? .3 : .74;METALLIC=0.;SPECULAR=gel_surface ? .45 : .3;
 ALPHA=use_source_alpha ? original.a : 1.;ALPHA_SCISSOR_THRESHOLD=.12;
}
