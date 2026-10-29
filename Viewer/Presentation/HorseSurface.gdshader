shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
void fragment() {
 vec3 colour=texture(albedo_texture,UV).rgb;
 vec3 orm=texture(orm_texture,UV).rgb;
 // Preserve the source's per-texel metal/leather response when dyed.
 if(use_hue) {
  bool grey=max(max(colour.r,colour.g),colour.b)-min(min(colour.r,colour.g),colour.b)<.025;
  if(!partial_hue || grey) {
   float value=pow(clamp(max(max(colour.r,colour.g),colour.b),0.,1.),1./2.2);
   colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb;
  }
 }
 ALBEDO=colour;
 NORMAL_MAP=texture(normal_texture,UV).rgb;
 NORMAL_MAP_DEPTH=.65;
 ROUGHNESS=clamp(orm.g,.32,.95);
 METALLIC=orm.b;
}
