shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform vec3 coat_colour : source_color = vec3(.35,.6,.8);
uniform float coat_change = 1.;
uniform bool grey_coat = false;
uniform bool use_vertex_regions = false;
uniform bool show_regions = false;
uniform float magic_glow = 0.;
uniform vec3 magic_colour : source_color = vec3(0.);
void fragment(){
 vec3 source=texture(albedo_texture,UV).rgb;
 float detail=clamp(dot(source,vec3(.2126,.7152,.0722))/.03,.3,1.6);
 vec3 colour=coat_colour;
 // 0x4001 is the server's spectral marker, not a hues.mul dye index.
 if(use_hue && !partial_hue){colour=texture(hue_palette,vec2((floor(clamp(detail*.4,0.,1.)*31.)+.5)/32.,.5)).rgb;}
 if(use_hue && partial_hue && (max(source.r,max(source.g,source.b))-min(source.r,min(source.g,source.b)))<.01){colour=texture(hue_palette,vec2(.65,.5)).rgb;}
 float rim=pow(1.-max(dot(normalize(NORMAL),normalize(VIEW)),0.),2.);
 ALBEDO=colour*detail;EMISSION=colour*(.16+.55*rim);
 NORMAL_MAP=texture(normal_texture,UV).rgb;NORMAL_MAP_DEPTH=.45;
 ROUGHNESS=.65;METALLIC=0.;ALPHA=.43+.30*rim;
}
