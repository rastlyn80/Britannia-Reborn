shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec4 base_colour : source_color = vec4(1.0);
uniform bool has_texture = true;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform bool cutout = false;
uniform bool cosmetic = false;
uniform bool has_normal = false;
uniform float pigmentation_gain = 1.8;
uniform float normal_strength = 1.0;
uniform float roughness = .8;
uniform float metalness = 0.0;
uniform vec4 emission_colour : source_color = vec4(0.0);
void fragment() {
 vec4 source = base_colour;
 if (has_texture) { source *= texture(source_texture,UV); }
 if (cutout && source.a < .35) { discard; }
 vec3 colour = source.rgb;
 bool grey = max(max(colour.r,colour.g),colour.b)-min(min(colour.r,colour.g),colour.b)<.025;
 if (use_hue && (!partial_hue || grey)) {
  // Texture sampling is linear; convert the intensity back to the native
  // sRGB palette index before sampling the source-colour hue texture.
  float intensity = pow(clamp(max(max(colour.r,colour.g),colour.b),0.0,1.0),1.0/2.2);
  // Remove the dark authored hair pigmentation before applying a native dye;
  // retain strand shading without forcing blond/silver hues back to brown.
  if (cosmetic) { intensity = sqrt(clamp(intensity*pigmentation_gain,0.0,1.0)); }
  colour = texture(hue_palette,vec2((floor(intensity*31.0)+.5)/32.0,.5)).rgb;
 }
 ALBEDO = colour;
 if (has_normal) { NORMAL_MAP = texture(normal_texture,UV).rgb; NORMAL_MAP_DEPTH = normal_strength; }
 ROUGHNESS = roughness;
 METALLIC = metalness;
 EMISSION = emission_colour.rgb;
 SPECULAR = cutout ? .2 : .4;
}
