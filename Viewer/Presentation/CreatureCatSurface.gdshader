shader_type spatial;
render_mode cull_disabled;
uniform vec4 source_colour : source_color = vec4(.3,.3,.3,1.);
uniform bool pink_region=false;
uniform bool white_region=false;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform float coat_detail : hint_range(0.,1.)=.65;
uniform float coat_roughness : hint_range(.05,1.)=.88;
varying vec3 coat_position;
void vertex(){coat_position=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1.,0.,0.)),f.x),mix(hash(i+vec3(0.,1.,0.)),hash(i+vec3(1.,1.,0.)),f.x),f.y),
            mix(mix(hash(i+vec3(0.,0.,1.)),hash(i+vec3(1.,0.,1.)),f.x),mix(hash(i+vec3(0.,1.,1.)),hash(i+vec3(1.)),f.x),f.y),f.z);
}
void fragment(){
 // The original has no UV atlas. Procedural coat variation is explicitly
 // authored in source mesh coordinates, not claimed as recovered texture.
 float coarse=noise(coat_position*vec3(16.,22.,20.));
 float fine=noise(coat_position*vec3(115.,300.,135.));
 float stripes=smoothstep(.63,.95,sin(coat_position.x*6.+sin(coat_position.z*5.)*.6));
 float detail=mix(1.,(.91+.14*coarse+.08*fine)*(1.-.19*stripes),coat_detail);
 vec3 colour=source_colour.rgb;
 if(pink_region){colour=mix(vec3(.25,.085,.11),colour,.22);}
 else{colour*=detail;}
 if(use_hue && (!partial_hue || (!pink_region && !white_region))){
  float value=max(colour.r,max(colour.g,colour.b));
  float index=floor(pow(clamp(value,0.,1.),1./2.2)*31.);
  colour=texture(hue_palette,vec2((index+.5)/32.,.5)).rgb*mix(.65,1.1,clamp(value*2.,0.,1.))*detail;
 }
 ALBEDO=colour;ROUGHNESS=clamp(coat_roughness+(fine-.5)*.08,.05,1.);METALLIC=0.;SPECULAR=.24;
}
