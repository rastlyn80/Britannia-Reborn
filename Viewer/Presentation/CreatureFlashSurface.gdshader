shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform float gain=0.;
uniform vec4 uv_rect=vec4(0.,0.,1.,1.);
void fragment(){
 vec4 source=texture(albedo_texture,UV);
 vec3 tint=use_hue ? texture(hue_palette,vec2(.85,.5)).rgb : vec3(1.);
 vec2 local=(UV-uv_rect.xy)/max(uv_rect.zw-uv_rect.xy,vec2(.0001));
 vec2 point=(local-.5)*2.;
 float glow=pow(max(0.,1.-dot(point,point)),2.);
 ALBEDO=source.rgb*tint;
 ALPHA=source.a*gain*glow*.18;
}
