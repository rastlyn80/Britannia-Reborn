shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_disabled;
uniform float phase=0.0;
uniform bool core=false;
uniform float density=1.0;
uniform sampler2D hue_palette : source_color, filter_linear, repeat_disable;
uniform bool use_hue=false;
uniform bool partial_hue=false;
void fragment(){
 float face=abs(dot(normalize(NORMAL),normalize(VIEW)));
 float pulse=.85+.15*sin(phase*3.+UV.x*18.+UV.y*7.);
 float ridge=.72+.28*pow(sin(UV.x*37.7+UV.y*13.-phase*2.),2.);
 float gain=core ? pow(face,.8) : pow(max(0.,1.-UV.y),1.3)*pow(face,1.2)*pulse*ridge;
 vec3 energy=vec3(.24,.075,.40);
 if(use_hue && (!partial_hue || !core))energy=texture(hue_palette,vec2(.65+.25*UV.y,.5)).rgb;
 float rim=core ? pow(1.-face,1.4) : .5+.5*UV.y;
 ALBEDO=mix(vec3(.008,.006,.018),energy*.65,rim);
 EMISSION=energy*rim*(core ? .35 : .55);
 ALPHA=gain*density*(core ? .96 : .70);
}
