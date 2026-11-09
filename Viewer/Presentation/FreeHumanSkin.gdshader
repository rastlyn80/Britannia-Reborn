shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_specular : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float normal_strength : hint_range(0.0,1.0) = 0.18;
uniform float skin_roughness : hint_range(0.3,0.9) = 0.60;
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform sampler2D form_hue_palette : source_color, filter_nearest;
uniform bool use_form_hue = false;
void fragment() {
 vec3 colour = texture(albedo_texture,UV).rgb;
 float oil = texture(skin_specular,UV).r;
 if (use_form_hue) {
  float level = pow(clamp(dot(colour,vec3(0.2126,0.7152,0.0722)),0.0,1.0),1.0/2.2);
  colour = texture(form_hue_palette,vec2((floor(level*31.0)+0.5)/32.0,0.5)).rgb;
 }
 ALBEDO = colour * skin_tint.rgb;
 // Retain fine authored detail while suppressing the mismatched broad body-
 // hair/muscle relief. Geometry supplies anatomy; albedo supplies pigmentation.
 vec2 fine = texture(skin_normal,UV).rg;
 vec2 broad = textureLod(skin_normal,UV,4.0).rg;
 vec2 detail = (fine - mix(broad,vec2(0.5),0.12)) * 2.0;
 NORMAL_MAP = vec3(detail * 0.5 + 0.5, sqrt(max(0.0,1.0-dot(detail,detail))) * 0.5 + 0.5);
 NORMAL_MAP_DEPTH = normal_strength;
 ROUGHNESS = clamp(skin_roughness + 0.06 - oil * 0.14, 0.46, 0.75);
 SPECULAR = 0.28 + oil * 0.035;
 METALLIC = 0.0;
 #if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
 #ifndef HUMAN_NO_SSS
 SSS_STRENGTH = 0.08;
 #endif
 #endif
}
