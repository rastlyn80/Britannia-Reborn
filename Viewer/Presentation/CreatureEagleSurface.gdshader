shader_type spatial;
render_mode cull_disabled;
uniform vec4 source_colour : source_color = vec4(.15,.08,.045,1.);
uniform bool feather_region=true;
uniform bool white_region=false;
uniform bool tintable_partial=true;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform float feather_detail : hint_range(0.,1.)=.7;
uniform float feather_roughness : hint_range(.05,1.)=.86;
varying vec3 feather_position;
void vertex(){feather_position=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void fragment(){
 // Donor geometry has four flat material regions and no UV map. These
 // restrained feather/barb marks are authored procedural detail, not a scan.
 vec3 p=feather_position;
 float row=floor(p.z*18.);
 float shaft=fract(p.y*13.+mod(row,2.)*.5);
 float edge=pow(abs(shaft-.5)*2.,7.);
 float barb=.5+.5*sin(p.y*190.+abs(shaft-.5)*25.+p.x*16.);
 float grain=hash(floor(p*400.));
 float detail=mix(1.,.92+.09*barb+.025*grain-.12*edge,feather_detail);
 vec3 colour=source_colour.rgb;
 if(feather_region){
  colour*=detail;
  if(white_region){colour=mix(colour,vec3(.72,.69,.61),.12);}
 }
 if(use_hue && (!partial_hue || tintable_partial)){
  float value=max(colour.r,max(colour.g,colour.b));
  float index=floor(pow(clamp(value,0.,1.),1./2.2)*31.);
  colour=texture(hue_palette,vec2((index+.5)/32.,.5)).rgb*mix(.68,1.08,clamp(value*2.,0.,1.));
  if(feather_region){colour*=detail;}
 }
 ALBEDO=colour;
 ROUGHNESS=feather_region ? clamp(feather_roughness+(barb-.5)*.07,.05,1.) : .64;
 METALLIC=0.;SPECULAR=feather_region ? .23 : .32;
}
