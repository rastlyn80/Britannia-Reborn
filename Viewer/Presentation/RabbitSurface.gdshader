shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_normal_texture=false;
uniform bool fur_cards=false;
uniform bool alpha_probe=false;
uniform bool use_source_alpha=true;
uniform float normal_strength : hint_range(0.,1.)=.35;
void fragment(){
 vec4 source=texture(albedo_texture,UV);
 float value=dot(source.rgb,vec3(.2126,.7152,.0722));
 // Authored fur dye regions, not a recovered UO partial-hue mask. Keep the
 // artist's dark eyes/mouth and pink inner-ear/nose colour distinguishable.
 float eye=fur_cards ? 0. : 1.-smoothstep(.025,.10,max(source.r,max(source.g,source.b)));
 float pink=fur_cards ? 0. : smoothstep(1.3,1.8,source.r/max(.001,source.g))*smoothstep(.35,.55,source.b/max(.001,source.r));
 float mask=(1.-eye)*(partial_hue ? 1.-pink : 1.);
 vec3 colour=source.rgb;
 if(use_hue){
  float index=floor(pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2)*31.);
  vec3 dyed=texture(hue_palette,vec2((index+.5)/32.,.5)).rgb*clamp(value*2.,.35,1.2);
  colour=mix(colour,dyed,mask);
 }
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour;
 if(use_normal_texture){NORMAL_MAP=texture(normal_texture,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
 ROUGHNESS=mix(fur_cards ? .95 : .9,.28,eye);METALLIC=0.;SPECULAR=mix(.2,.45,eye);
 ALPHA=use_source_alpha ? source.a : 1.;ALPHA_SCISSOR_THRESHOLD=.35;
}
