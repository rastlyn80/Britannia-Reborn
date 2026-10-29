shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;
uniform vec3 coat_colour : source_color = vec3(.30,.20,.12);
uniform float coat_change = 0.;
uniform bool grey_coat = false;
uniform bool show_regions = false;
uniform bool use_vertex_regions = false;
varying vec3 bind_position;
void vertex(){bind_position=VERTEX;}
void fragment() {
 vec3 colour=texture(albedo_texture,UV).rgb;
 vec3 orm=texture(orm_texture,UV).rgb;
 // The source ORM separates rough fur from smoother leather and metal.
 // Tint the fur region, preserving the original tack, muzzle and hooves.
 float brown=smoothstep(.02,.08,(colour.r-colour.b)/max(colour.r,.0001));
 float torso=smoothstep(.22,.28,abs(bind_position.x))*smoothstep(.75,.90,bind_position.y)*(1.-smoothstep(1.45,1.53,bind_position.y))*smoothstep(-1.05,-.85,bind_position.z)*(1.-smoothstep(.2,.4,bind_position.z));
 float region=COLOR.r;
 float fur=(use_vertex_regions ? region : max(smoothstep(.525,.555,orm.g)*brown,torso))*(1.-smoothstep(.05,.35,orm.b))*smoothstep(.45,.95,bind_position.y)*smoothstep(-1.15,-.95,bind_position.z);
 float detail=pow(clamp(dot(colour,vec3(.2126,.7152,.0722))/.030,.13,2.5),.72);
 vec3 coat=coat_colour*detail;
 if(grey_coat){
  float dapple=sin(bind_position.x*53.)*sin(bind_position.y*43.)*sin(bind_position.z*57.);
  coat*=1.+.07*dapple;
 }
 colour=mix(colour,coat,fur*coat_change);
 // Preserve native hue identity, with a documented fur-region interpretation
 // so a dyed horse does not also become a painted saddle and suit of tack.
 if(use_hue) {
  bool grey=grey_coat || (max(max(colour.r,colour.g),colour.b)-min(min(colour.r,colour.g),colour.b))/max(max(max(colour.r,colour.g),colour.b),.0001)<.06;
  if(!partial_hue || grey) {
   float value=pow(clamp(max(max(colour.r,colour.g),colour.b),0.,1.),1./2.2);
   vec3 dyed=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb;
   colour=mix(colour,dyed*clamp(detail,.45,1.3),fur);
  }
 }
 ALBEDO=colour;
 if(show_regions){ALBEDO=vec3(0.);EMISSION=vec3(fur);}
 NORMAL_MAP=texture(normal_texture,UV).rgb;
 NORMAL_MAP_DEPTH=.65;
 ROUGHNESS=clamp(orm.g,.32,.95);
 METALLIC=orm.b;
}
