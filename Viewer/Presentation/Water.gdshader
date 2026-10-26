shader_type spatial;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
// River and sea surfaces. Waves are evaluated as a world-space normal so every
// water mesh (subdivided river planes, merged sea quads) shades continuously,
// independent of mesh UVs/tangents and tile boundaries.
uniform vec4 water_color : source_color = vec4(0.018,0.055,0.068,1.0);
uniform vec4 shallow_color : source_color = vec4(0.06,0.15,0.14,1.0);
uniform vec2 source_origin=vec2(0.0);
uniform float wave_strength=1.0;
uniform float time_override=-1.0;
uniform sampler2D shore_data : filter_linear, repeat_disable;
uniform vec4 shore_rect=vec4(0.0,0.0,1.0,1.0);
uniform bool has_shore=false;
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
void fragment(){
 float t=time_override>=0.0?time_override:TIME;
 vec2 p=world_uv;
 // Long directional swells plus two scrolling ripple layers.
 vec2 slope=swell(p,normalize(vec2(0.8,0.6)),0.55,0.9,0.05,t)
  +swell(p,normalize(vec2(-0.4,0.9)),0.9,1.2,0.03,t)
  +swell(p,normalize(vec2(0.95,-0.3)),1.6,1.7,0.015,t);
 // Fine ripples fade with distance to avoid aliasing glitter on far water.
 float detail=1.0-smoothstep(0.05,0.6,length(fwidth(p)));
 slope+=(ripple_slope(p,2.1,t)*0.022+ripple_slope(p*1.7+3.0,4.3,t*1.3)*0.008)*detail;
 slope*=wave_strength;
 vec3 world_normal=normalize(vec3(-slope.x,1.0,-slope.y));
 NORMAL=normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
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
 // Large-scale tonal drift so open water is not a uniform sheet.
 color*=mix(0.85,1.12,surface_fbm(p*0.04+vec2(t*0.003,0.0)));
 ALBEDO=mix(color,vec3(0.62,0.66,0.62),foam);
 ROUGHNESS=mix(0.09,0.6,foam);
 METALLIC=0.0;
 SPECULAR=0.55;
}
