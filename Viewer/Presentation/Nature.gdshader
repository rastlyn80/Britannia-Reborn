shader_type spatial;
render_mode cull_disabled;
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D source_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal=false;
uniform bool camera_fade=false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float base_y = 0.0;
uniform float plant_height = 1.0;
uniform float amplitude = 0.1;
uniform float flutter = 0.01;
uniform vec2 source_origin = vec2(0.0);
uniform float time_override = -1.0;
void vertex() {
 float t = time_override >= 0.0 ? time_override : TIME;
 float weight = pow(clamp((VERTEX.y-base_y)/max(plant_height,0.001),0.0,1.0),2.0);
 vec2 anchor = (MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xz+source_origin;
 float phase = dot(anchor,vec2(0.13,0.19));
 float gust = sin(t*0.8+phase)*0.65+sin(t*1.37+phase*0.71)*0.35;
 vec3 motion = vec3(gust,0.0,gust*0.42)*amplitude*weight;
 motion.x += sin(t*3.1+VERTEX.x*5.0+phase)*flutter*weight;
 VERTEX += (inverse(MODEL_MATRIX)*vec4(motion,0.0)).xyz;
}
void fragment() {
 vec4 source = texture(source_texture,UV);
 // A tiny dithered clearance around the lens keeps close leaves from filling
 // the screen. Only foliage enables this; trunks retain their solid silhouette.
 if(camera_fade){
  float visibility=smoothstep(0.35,1.1,length(VERTEX));
  float dither=fract(52.9829189*fract(dot(FRAGCOORD.xy,vec2(0.06711056,0.00583715))));
  if(visibility<dither){discard;}
 }
 float luminance = dot(source.rgb,vec3(0.2126,0.7152,0.0722));
 ALBEDO = mix(vec3(luminance),source.rgb,0.78)*tint.rgb;
 ROUGHNESS = 0.88;
 SPECULAR = 0.22;
 if(has_normal){ NORMAL_MAP=texture(source_normal,UV).rgb; NORMAL_MAP_DEPTH=0.5; }
 ALPHA_SCISSOR_THRESHOLD = 0.4;
 ALPHA = source.a;
}
