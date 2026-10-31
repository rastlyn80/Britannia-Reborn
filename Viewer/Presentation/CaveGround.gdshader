shader_type spatial;
render_mode cull_disabled;
// Underground terrain (Underground.gd, docs/DUNGEONS.md): districts that hold
// UO's black void and cave land are drawn as a cave. Steep land is wet rock,
// flat land is gravel, flagstones (stone land) or moss (grass land), and every
// surface fades to black above the viewer's head, so cave walls rise into
// darkness instead of ending in the sunlit void plateau 2D hides.
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform vec2 source_origin=vec2(0.0);
uniform float viewer_height=0.0;
// 0 outdoors (plain cave colours), 1 underground (the ceiling darkness).
uniform float enclosure=1.0;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 rock_scale=vec2(1.0);
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 gravel_scale=vec2(1.0);
uniform sampler2D flag_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flag_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D flag_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 flag_scale=vec2(1.0);
uniform sampler2D moss_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D moss_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 moss_scale=vec2(1.0);
varying vec3 world_position;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
vec3 triplanar(sampler2D map, vec3 p, vec3 w, vec2 scale){
 return texture(map,p.zy*scale).rgb*w.x+texture(map,p.xz*scale).rgb*w.y+texture(map,p.xy*scale).rgb*w.z;
}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 w=pow(abs(n),vec3(4.0));
 w/=max(dot(w,vec3(1.0)),0.001);
 // Land families by the baked source colour (Reconstruction.terrain_color):
 // grass is green, dirt warm, stone neutral, cave/void/rock a cool grey.
 float grass=smoothstep(0.01,0.07,COLOR.g-COLOR.r);
 float dirt=smoothstep(0.05,0.12,COLOR.r-COLOR.b);
 float stone=(1.0-smoothstep(0.01,0.035,abs(COLOR.b-COLOR.g)-0.002))*(1.0-grass)*(1.0-dirt);
 float broad=surface_fbm(UV*0.25);
 vec3 gravel_tex=texture(gravel_albedo,UV*gravel_scale).rgb;
 // Grey cave grit: the dirt path texture, mostly desaturated.
 vec3 gravel=mix(vec3(dot(gravel_tex,vec3(0.2126,0.7152,0.0722))),gravel_tex,0.35)*vec3(0.78,0.76,0.74);
 vec3 flags=texture(flag_albedo,UV*flag_scale).rgb*vec3(0.55,0.55,0.56);
 vec3 moss=texture(moss_albedo,UV*moss_scale).rgb*vec3(0.42,0.5,0.36);
 vec3 ground=mix(gravel,flags,stone);
 ground=mix(ground,gravel*vec3(0.95,0.82,0.66),dirt);
 ground=mix(ground,moss,grass);
 ground*=mix(0.78,1.08,broad);
 float slope=1.0-abs(n.y);
 float cliff=smoothstep(0.22,0.55,slope);
 vec3 rock=triplanar(rock_albedo,world_position,w,rock_scale)*vec3(0.5,0.48,0.46);
 float strata=surface_noise(vec2(world_position.x+world_position.z,world_position.y)*vec2(0.4,5.0));
 rock*=mix(0.75,1.08,strata);
 vec3 color=mix(ground,rock,cliff);
 // Rock above the viewer fades to black: the walls rise into darkness.
 float above=world_position.y-viewer_height;
 float ceiling=smoothstep(1.4,3.6,above)*enclosure;
 ALBEDO=color*(1.0-ceiling);
 vec3 ground_n=mix(mix(texture(gravel_normal,UV*gravel_scale).rgb,texture(flag_normal,UV*flag_scale).rgb,stone),texture(moss_normal,UV*moss_scale).rgb,grass);
 vec2 cliff_uv=abs(n.x)>abs(n.z)?world_position.zy:world_position.xy;
 NORMAL_MAP=mix(ground_n,texture(rock_normal,cliff_uv*rock_scale).rgb,cliff);
 NORMAL_MAP_DEPTH=0.9;
 float ground_rough=mix(texture(gravel_roughness,UV*gravel_scale).r,texture(flag_roughness,UV*flag_scale).r,stone);
 // Damp cave rock catches the torch.
 ROUGHNESS=clamp(mix(ground_rough,texture(rock_roughness,cliff_uv*rock_scale).r*0.75,cliff),0.35,0.95);
 SPECULAR=mix(0.3,0.0,ceiling);
}
