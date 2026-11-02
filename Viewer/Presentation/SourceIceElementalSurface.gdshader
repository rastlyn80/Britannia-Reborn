shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform float detail_strength=.32;
uniform float ice_roughness=.24;
void fragment(){
 vec3 colour=texture(albedo_texture,UV).rgb;
 float brightness=dot(colour,vec3(.2126,.7152,.0722));
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(texture(albedo_texture,UV-vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float right=dot(texture(albedo_texture,UV+vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float up=dot(texture(albedo_texture,UV-vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 float down=dot(texture(albedo_texture,UV+vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 // Match the shared neutral-texel partial dye rule. This is an authored
 // interpretation, not a recovered original per-pixel material mask.
 float spread=max(colour.r,max(colour.g,colour.b))-min(colour.r,min(colour.g,colour.b));
 if(use_hue && (!partial_hue || spread<.025)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb;
 }
 // Small atlas-derived relief, rather than moving or inflating the body.
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 ALBEDO=colour;
 METALLIC=0.;SPECULAR=.5;
 ROUGHNESS=clamp(ice_roughness+brightness*.16,.08,.65);
 CLEARCOAT=.65;CLEARCOAT_ROUGHNESS=.12;
}
