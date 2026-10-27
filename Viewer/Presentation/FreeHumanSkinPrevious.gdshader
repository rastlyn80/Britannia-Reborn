shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_specular : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float normal_strength : hint_range(0.0,1.0) = 0.28;
uniform float skin_roughness : hint_range(0.3,0.9) = 0.58;
void fragment() {
 vec3 colour = texture(albedo_texture,UV).rgb;
 float oil = texture(skin_specular,UV).r;
 ALBEDO = colour;
 NORMAL_MAP = texture(skin_normal,UV).rgb;
 NORMAL_MAP_DEPTH = normal_strength;
 ROUGHNESS = clamp(skin_roughness + 0.16 - oil * 0.30, 0.34, 0.83);
 SPECULAR = 0.30 + oil * 0.08;
 METALLIC = 0.0;
 #if CURRENT_RENDERER != RENDERER_COMPATIBILITY
 SSS_STRENGTH = 0.10;
 #endif
}
