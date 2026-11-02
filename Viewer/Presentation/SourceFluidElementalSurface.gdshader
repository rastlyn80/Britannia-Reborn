shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_source_alpha=true;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool poison_surface=false;
uniform float fluid_time=0.;
uniform float detail_strength=.3;
uniform float gel_strength=1.;
float hash21(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float grain(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash21(i),hash21(i+vec2(1.,0.)),f.x),mix(hash21(i+vec2(0.,1.)),hash21(i+vec2(1.,1.)),f.x),f.y);}
float surface(vec2 p){return grain(p*144.+vec2(fluid_time*.13,0.))*.65+grain(p*311.)*.25+grain(p*47.-vec2(0.,fluid_time*.07))*.1;}
void fragment(){
 vec4 original=texture(albedo_texture,UV);vec3 colour=original.rgb;
 float luma=dot(colour,vec3(.2126,.7152,.0722));float high=max(colour.r,max(colour.g,colour.b));
 vec3 chroma=colour/max(.025,high);float soft=.13+.65*pow(clamp(high,0.,1.),.75);
 colour=mix(colour,chroma*soft,gel_strength);
 float mottling=surface(UV);colour*=mix(1.,.9+.2*mottling,gel_strength);
 if(use_hue && (!partial_hue || UV.y>.36)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(luma*1.6,.35,1.1);
 }
 vec2 step_uv=vec2(1./1024.,0.);float dx=surface(UV-step_uv)-surface(UV+step_uv);float dy=surface(UV-step_uv.yx)-surface(UV+step_uv.yx);
 NORMAL_MAP=normalize(vec3(dx,dy,1./max(.001,detail_strength)))*.5+.5;
 ALBEDO=colour*.85;ROUGHNESS=poison_surface ? .47 : .32;METALLIC=0.;SPECULAR=.36;
 EMISSION=colour*(poison_surface ? .025 : .012);ALPHA=use_source_alpha ? texture(source_atlas,UV).a : 1.;ALPHA_SCISSOR_THRESHOLD=.12;
}
