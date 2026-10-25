shader_type spatial;
render_mode cull_disabled;
uniform sampler2D stone_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
 float broad=noise(UV*0.55)*0.6+noise(UV*2.4)*0.4;
 vec3 ground=COLOR.rgb*mix(0.88,1.12,broad);
 vec2 paving=UV*vec2(2.15,1.65);
 paving.x+=mod(floor(paving.y),2.0)*0.5;
 vec2 f=fract(paving);
 vec2 edge=min(f,1.0-f);
 float aa=length(fwidth(paving));
 float mortar=smoothstep(0.018,0.065+aa,min(edge.x,edge.y));
 float variation=mix(0.88,1.10,hash(floor(paving)));
 vec3 texture_detail=texture(stone_detail,UV*0.32).rgb;
 float stone_light=dot(texture_detail,vec3(0.2126,0.7152,0.0722));
 vec3 stone=vec3(0.19,0.21,0.205)*variation*mix(0.80,1.12,stone_light);
 stone=mix(vec3(0.11,0.12,0.10),stone,mortar);
 float stone_weight=smoothstep(0.12,0.88,UV2.x);
 vec3 color=mix(ground,stone,stone_weight);
 float plank=fract(UV.x*3.0);
 float seam=smoothstep(0.015,0.04+fwidth(UV.x)*3.0,min(plank,1.0-plank));
 vec3 wood=COLOR.rgb*mix(0.72,1.0,seam)*mix(0.93,1.07,noise(UV*vec2(20.0,0.7)));
 color=mix(color,wood,smoothstep(0.12,0.88,UV2.y));
 ALBEDO=color;
 NORMAL_MAP=mix(vec3(0.5,0.5,1.0),texture(stone_normal,UV*0.32).rgb,stone_weight*0.4);
 NORMAL_MAP_DEPTH=0.55;
 ROUGHNESS=0.94;
 SPECULAR=0.14;
}
