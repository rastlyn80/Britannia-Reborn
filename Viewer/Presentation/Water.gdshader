shader_type spatial;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
// River and sea surfaces. Waves are evaluated as a world-space normal so every
// water mesh (subdivided river planes, merged sea quads) shades continuously,
// independent of mesh UVs/tangents and tile boundaries. The scene behind the
// surface is refracted and absorbed by water depth (read from the depth
// buffer), so beds, piers and banks show through shallows and fade in the deep.
uniform vec4 water_color : source_color = vec4(0.018,0.055,0.068,1.0);
uniform vec4 shallow_color : source_color = vec4(0.06,0.15,0.14,1.0);
uniform vec2 source_origin=vec2(0.0);
uniform float wave_strength=1.0;
uniform float time_override=-1.0;
uniform sampler2D shore_data : filter_linear, repeat_disable;
uniform vec4 shore_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool has_shore=false;
// Optional owner-licensed detail (local only): tileable normal map + foam mask.
uniform sampler2D detail_normal : filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_mask : filter_linear_mipmap, repeat_enable;
uniform bool has_detail=false;
// Per-metre absorption (red goes first) and the distance light still reaches.
uniform vec3 absorption=vec3(0.85,0.30,0.24);
uniform float refraction_strength=0.035;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
varying vec2 world_uv;
void vertex(){
 world_uv=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz+source_origin;
}
vec2 swell(vec2 p, vec2 dir, float freq, float speed, float amp, float t){
 float phase=dot(p,dir)*freq+t*speed;
 return dir*cos(phase)*freq*amp;
}
// Smooth analytic ripples: a fan of short waves with incommensurate directions.
vec2 ripple_slope(vec2 p, float scale, float t){
 vec2 slope=vec2(0.0);
 for(int i=0;i<6;i++){
  float angle=float(i)*1.047+0.37;
  vec2 dir=vec2(cos(angle),sin(angle));
  float freq=scale*(1.0+float(i)*0.37);
  slope+=dir*cos(dot(p,dir)*freq+t*(1.3+float(i)*0.21))*freq;
 }
 return slope/6.0;
}
// Linear view-space distance of the opaque scene at a screen position.
float scene_distance(vec2 uv, mat4 inv_projection){
 float raw=texture(depth_texture,uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 vec4 ndc=vec4(uv*2.0-1.0,raw*2.0-1.0,1.0);
#else
 vec4 ndc=vec4(uv*2.0-1.0,raw,1.0);
#endif
 vec4 view=inv_projection*ndc;
 return -view.z/view.w;
}
void fragment(){
 float t=time_override>=0.0?time_override:TIME;
 vec2 p=world_uv;
 // Long directional swells plus fine detail.
 vec2 slope=swell(p,normalize(vec2(0.8,0.6)),0.55,0.9,0.05,t)
  +swell(p,normalize(vec2(-0.4,0.9)),0.9,1.2,0.03,t)
  +swell(p,normalize(vec2(0.95,-0.3)),1.6,1.7,0.015,t);
 float detail=1.0-smoothstep(0.05,0.6,length(fwidth(p)));
 if(has_detail){
  // Two counter-scrolling samples of a real water normal map; mipmaps keep
  // the far surface calm instead of glittering.
  vec2 a=texture(detail_normal,p*0.16+vec2(t*0.011,t*0.006)).rg*2.0-1.0;
  vec2 b=texture(detail_normal,p*0.37+vec2(-t*0.017,t*0.013)).rg*2.0-1.0;
  slope+=(a*0.20+b*0.12);
 }else{
  slope+=(ripple_slope(p,2.1,t)*0.022+ripple_slope(p*1.7+3.0,4.3,t*1.3)*0.008)*detail;
 }
 slope*=wave_strength;
 vec3 world_normal=normalize(vec3(-slope.x,1.0,-slope.y));
 NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);

 // Water thickness along the view ray, then refraction that never pulls in
 // objects standing in front of the surface.
 float surface=-VERTEX.z;
 float thickness=max(scene_distance(SCREEN_UV,INV_PROJECTION_MATRIX)-surface,0.0);
 vec2 offset=slope*refraction_strength*clamp(thickness,0.0,1.0);
 vec2 refract_uv=SCREEN_UV+offset;
 float refracted=scene_distance(refract_uv,INV_PROJECTION_MATRIX)-surface;
 if(refracted<0.0){refract_uv=SCREEN_UV;refracted=thickness;}
 vec3 behind=textureLod(screen_texture,refract_uv,0.0).rgb;
 vec3 transmit=exp(-absorption*max(refracted,0.0));

 vec3 color=water_color.rgb;
 float foam=0.0;
 if(has_shore){
  vec3 shore=texture(shore_data,(p-shore_rect.xy)/shore_rect.zw).rgb;
  float shallow=1.0-smoothstep(0.2,1.8,shore.b);
  color=mix(color,shallow_color.rgb,shallow*0.75);
  float edge=1.0-smoothstep(0.2,1.2,abs(shore.r));
  float wash=sin(shore.r*7.0-t*0.8+surface_noise(p*1.5)*3.0)*0.5+0.5;
  foam=edge*smoothstep(0.6,0.92,wash)*(0.35+0.25*surface_noise(p*6.0+t*0.2));
 }
 // Contact foam wherever the surface meets banks, piers, hulls or rocks.
 float contact=1.0-smoothstep(0.04,0.35,thickness);
 float mask=has_detail?texture(foam_mask,p*0.45+vec2(t*0.02,-t*0.015)).r:surface_noise(p*5.0+t*0.3);
 foam=max(foam,contact*smoothstep(0.25,0.75,mask+contact*0.35));
 // Large-scale tonal drift so open water is not a uniform sheet.
 color*=mix(0.85,1.12,surface_fbm(p*0.04+vec2(t*0.003,0.0)));

 // Deep water is its own colour; shallows show the absorbed scene behind.
 float clarity=dot(transmit,vec3(0.3333));
 ALBEDO=mix(color*(1.0-clarity),vec3(0.62,0.66,0.62),foam);
 EMISSION=behind*transmit*(1.0-foam)*0.92;
 ROUGHNESS=mix(0.04,0.6,foam);
 METALLIC=0.0;
 SPECULAR=0.55;
}
