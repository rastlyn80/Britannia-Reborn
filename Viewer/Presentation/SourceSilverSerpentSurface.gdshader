shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform float detail_strength=.35;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
uniform bool darken_authored_eyes=true;
uniform float albedo_gain=.68;
float scale_relief(vec2 uv){
 vec2 p=uv*vec2(76.,110.);p.x+=mod(floor(p.y),2.)*.5;
 vec2 f=fract(p)-.5;float height=smoothstep(.52,.08,length(f*vec2(.85,1.)));
 return height*.7+sin(uv.x*621.)*sin(uv.y*773.)*.06;
}
void fragment(){
 vec4 source=texture(albedo_texture,UV);vec3 colour=source.rgb;
 if(darken_authored_eyes && UV.x<.25 && UV.y<.65 && colour.r>colour.g*1.4 && colour.r>colour.b*1.3){float grey=dot(colour,vec3(.2126,.7152,.0722))*.6;colour=vec3(grey);}
 float relief=scale_relief(UV);vec2 delta=vec2(1./2048.,0.);
 float dx=scale_relief(UV-delta)-scale_relief(UV+delta);float dy=scale_relief(UV-delta.yx)-scale_relief(UV+delta.yx);
 NORMAL_MAP=normalize(vec3(dx,dy,1./max(.001,detail_strength)))*.5+.5;
 vec3 original=texture(source_atlas,UV).rgb;
 float saturation=(max(original.r,max(original.g,original.b))-min(original.r,min(original.g,original.b)))/max(.001,max(original.r,max(original.g,original.b)));
 if(use_hue && (!partial_hue || saturation<.15)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(dot(colour,vec3(.2126,.7152,.0722))*2.,.4,1.3);
 }
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour*(albedo_gain+.06*relief);ROUGHNESS=.62;SPECULAR=.28;METALLIC=0.;
 ALPHA=use_source_alpha ? texture(source_atlas,UV).a : 1.;ALPHA_SCISSOR_THRESHOLD=.12;
}
