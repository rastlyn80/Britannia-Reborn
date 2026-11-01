shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform float detail_strength : hint_range(0.,1.)=.32;
uniform float fur_roughness : hint_range(.05,1.)=.9;
void fragment(){
 vec3 source=texture(albedo_texture,UV).rgb;
 // The source's red eye is changed by material interpretation, with its
 // highlight retained. Pink ears/nose/tail contain considerably more blue.
 float eye=smoothstep(1.7,2.7,source.r/max(.001,source.g))*
           (1.-smoothstep(.08,.22,source.b/max(.001,source.r)));
 float pink=smoothstep(1.15,1.7,source.r/max(.001,source.g))*smoothstep(.2,.35,source.b/max(.001,source.r));
 float value=dot(source,vec3(.2126,.7152,.0722));
 vec3 fur=mix(vec3(value)*vec3(.95,.82,.68),source,.35);
 vec3 colour=mix(fur,source,pink);
 colour=mix(colour,vec3(value*.1),eye);
 float dye_mask=partial_hue ? (1.-pink)*(1.-eye) : 1.-eye;
 if(use_hue){
  float index=floor(pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2)*31.);
  vec3 dyed=texture(hue_palette,vec2((index+.5)/32.,.5)).rgb*clamp(value*2.,.35,1.2);
  colour=mix(colour,dyed,dye_mask);
 }
 // Small albedo-derived relief only; this is not a sculpted fur normal map.
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float dx=dot(texture(albedo_texture,UV-vec2(texel.x,0.)).rgb-texture(albedo_texture,UV+vec2(texel.x,0.)).rgb,vec3(.3333));
 float dy=dot(texture(albedo_texture,UV-vec2(0.,texel.y)).rgb-texture(albedo_texture,UV+vec2(0.,texel.y)).rgb,vec3(.3333));
 NORMAL_MAP=normalize(vec3(dx,-dy,1./max(.01,detail_strength)))*.5+.5;
 ALBEDO=colour;ROUGHNESS=mix(fur_roughness,.27,eye);METALLIC=0.;SPECULAR=mix(.22,.45,eye);
}
