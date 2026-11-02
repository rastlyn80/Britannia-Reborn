shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_specular : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform float normal_strength=.18;
uniform float skin_roughness=.6;
uniform vec4 skin_tint : source_color=vec4(1.);
varying vec3 paint_position;
void vertex(){paint_position=CUSTOM0.xyz;}
float spiral(vec2 p,vec2 centre,float radius,float turn){
 vec2 q=p-centre;float r=length(q);float angle=atan(q.y,q.x)*turn;
 float pitch=radius/2.25;float distance=abs(mod(r-angle*pitch/6.2831853+pitch*.5,pitch)-pitch*.5);
 float aa=max(fwidth(distance),.0006);
 return (1.-smoothstep(.0035-aa,.0035+aa,distance))*(1.-smoothstep(radius-.006,radius,r));
}
void fragment(){
 vec3 source=texture(albedo_texture,UV).rgb;vec3 p=paint_position;
 float ink=spiral(p.xy,vec2(-.105,1.27),.105,1.);
 ink=max(ink,spiral(p.xy,vec2(.105,1.27),.105,-1.));
 ink=max(ink,spiral(p.xy,vec2(0.,1.06),.105,1.));
 ink=max(ink,spiral(p.xy,vec2(-.12,.68),.095,-1.));
 ink=max(ink,spiral(p.xy,vec2(.12,.68),.095,1.));
 ink=max(ink,spiral(p.xy,vec2(-.105,.32),.075,1.));
 ink=max(ink,spiral(p.xy,vec2(.105,.32),.075,-1.));
 ink=max(ink,spiral(p.xy,vec2(-.32,1.33),.075,-1.));
 ink=max(ink,spiral(p.xy,vec2(.32,1.33),.075,1.));
 ink=max(ink,spiral(p.xy,vec2(-.45,1.16),.065,1.));
 ink=max(ink,spiral(p.xy,vec2(.45,1.16),.065,-1.));
 vec2 orbital=(p.xy-vec2(.034*sign(p.x),1.67))/vec2(.034,.022);
 float eye_band=(1.-smoothstep(.85,1.2,length(orbital)))*smoothstep(.07,.10,p.z);
 ink=max(ink,eye_band);
 float luminance=dot(source,vec3(.2126,.7152,.0722));
 vec3 painted=mix(source,vec3(.69,.675,.64)*(.72+luminance*.46),.88);
 vec3 colour=mix(painted,vec3(.026,.023,.02),ink*.96)*skin_tint.rgb;
 if(use_hue){
  float high=max(colour.r,max(colour.g,colour.b));float low=min(colour.r,min(colour.g,colour.b));
  float neutral=1.-step(.18,(high-low)/max(.001,high));
  if(!partial_hue || neutral>.5)colour=texture(hue_palette,vec2((floor(pow(high,1./2.2)*31.)+.5)/32.,.5)).rgb;
 }
 ALBEDO=colour;
 vec2 fine=texture(skin_normal,UV).rg;vec2 broad=textureLod(skin_normal,UV,4.).rg;
 vec2 detail=(fine-mix(broad,vec2(.5),.12))*2.;
 NORMAL_MAP=vec3(detail*.5+.5,sqrt(max(0.,1.-dot(detail,detail)))*.5+.5);
 NORMAL_MAP_DEPTH=normal_strength;ROUGHNESS=.86;SPECULAR=.21;METALLIC=0.;
 #if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
 #ifndef HUMAN_NO_SSS
 SSS_STRENGTH=.035;
 #endif
 #endif
}
