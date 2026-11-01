shader_type spatial;
render_mode depth_prepass_alpha;
uniform float water_time=0.;
uniform float ripple_strength=.012;
uniform float roughness=.13;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
varying vec3 fluid_position;
void vertex(){
 fluid_position=VERTEX;
 float floor_mask=smoothstep(.015,.15,VERTEX.y);
 float wave=sin(VERTEX.y*18.-water_time*3.+VERTEX.x*9.)*sin(VERTEX.z*13.+water_time*1.8);
 VERTEX+=NORMAL*wave*ripple_strength*floor_mask;
}
void fragment(){
 float flow=sin(fluid_position.y*25.-water_time*4.+sin(fluid_position.x*14.+fluid_position.z*11.)*2.);
 float cross_wave=sin(fluid_position.z*32.+fluid_position.x*17.+water_time*2.);
 float foam=smoothstep(.72,.98,flow)*smoothstep(-.3,.7,cross_wave);
 vec3 colour=mix(vec3(.018,.115,.22),vec3(.045,.32,.43),flow*.5+.5);
 colour=mix(colour,vec3(.48,.83,.88),foam*.72);
 if(use_hue && (!partial_hue || foam>.18)){
  float value=clamp(.26+(flow*.5+.5)*.36+foam*.25,0.,1.);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb;
 }
 float fresnel=pow(1.-max(dot(normalize(NORMAL),normalize(VIEW)),0.),3.);
 ALBEDO=colour;
 ROUGHNESS=roughness+foam*.13;SPECULAR=.65;METALLIC=.08;
 CLEARCOAT=.8;CLEARCOAT_ROUGHNESS=.08;
 NORMAL_MAP=normalize(vec3(cos(fluid_position.x*18.+fluid_position.y*11.-water_time*3.)*.2,sin(fluid_position.z*22.+water_time*2.)*.18,1.))*.5+.5;
 EMISSION=colour*(.08+fresnel*.22);
 ALPHA=.88+fresnel*.12;
}
