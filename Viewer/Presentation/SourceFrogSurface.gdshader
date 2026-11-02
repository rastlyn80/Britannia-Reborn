shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
uniform float detail_strength=.22;
uniform float tongue_strength=.8;
void fragment(){
 vec4 original=texture(source_atlas,UV);
 vec3 colour=texture(albedo_texture,UV).rgb;
 float brightness=dot(colour,vec3(.2126,.7152,.0722));
 // COLOR.r is authored from the two terminal original tongue-chain weights,
 // not a guessed atlas rectangle or a recovered original dye/normal map.
 float tongue=clamp(COLOR.r*tongue_strength,0.,1.);
 colour=mix(colour,vec3(.44,.12,.105)*clamp(brightness*2.,.4,1.3),tongue);
 float source_max=max(original.r,max(original.g,original.b));
 float source_min=min(original.r,min(original.g,original.b));
 bool partial_region=(source_max-source_min)<.10 && COLOR.r<.1;
 if(use_hue && (!partial_hue || partial_region)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(brightness*1.6,.3,1.1);
 }
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(texture(albedo_texture,UV-vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float right=dot(texture(albedo_texture,UV+vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float up=dot(texture(albedo_texture,UV-vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 float down=dot(texture(albedo_texture,UV+vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour*.85;ROUGHNESS=mix(.62,.32,tongue);METALLIC=0.;SPECULAR=.32;
 ALPHA=use_source_alpha ? original.a : 1.;ALPHA_SCISSOR_THRESHOLD=.12;
}
