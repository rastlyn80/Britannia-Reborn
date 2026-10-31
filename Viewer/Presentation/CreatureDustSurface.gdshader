shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_alpha_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
void fragment(){
 vec3 source=texture(albedo_texture,UV).rgb;
 float lightness=dot(source,vec3(.2126,.7152,.0722));
 vec3 colour=vec3(.48,.56,.61);
 if(use_hue){colour=texture(hue_palette,vec2(.7,.5)).rgb;}
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour;
 float mask=use_source_alpha ? texture(source_alpha_texture,UV).a : 1.;
 ALPHA=mask*(alpha_probe ? 1. : .17*smoothstep(.015,.4,lightness));
 ROUGHNESS=1.;METALLIC=0.;
}
