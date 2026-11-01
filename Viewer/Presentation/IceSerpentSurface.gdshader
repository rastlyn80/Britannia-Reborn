shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D source_alpha_texture : filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform vec4 eye_registration=vec4(1.,0.,0.,0.);
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_source_alpha=true;
uniform bool alpha_probe=false;
uniform float albedo_gain : hint_range(0.,1.)=.62;
uniform float detail_strength : hint_range(0.,1.)=.15;
void fragment(){
 vec2 uv=UV;
 float head=smoothstep(.01,.03,uv.x)*(1.-smoothstep(.205,.225,uv.x))*smoothstep(.03,.12,uv.y)*(1.-smoothstep(.23,.31,uv.y));
 vec2 registered=vec2(eye_registration.x*uv.x+eye_registration.y,uv.y+eye_registration.z*uv.x+eye_registration.w);
 vec2 sample_uv=mix(uv,registered,head);
 vec3 colour=texture(albedo_texture,sample_uv).rgb;
 float lightness=dot(colour,vec3(.2126,.7152,.0722));
 vec2 texel=1./vec2(textureSize(albedo_texture,0));
 float left=dot(texture(albedo_texture,sample_uv-vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float right=dot(texture(albedo_texture,sample_uv+vec2(texel.x,0.)).rgb,vec3(.2126,.7152,.0722));
 float up=dot(texture(albedo_texture,sample_uv-vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 float down=dot(texture(albedo_texture,sample_uv+vec2(0.,texel.y)).rgb,vec3(.2126,.7152,.0722));
 // Fine relief is an albedo-derived approximation, not a recovered normal map.
 NORMAL_MAP=normalize(vec3((left-right)*detail_strength,(down-up)*detail_strength,1.))*.5+.5;
 float saturation=(max(colour.r,max(colour.g,colour.b))-min(colour.r,min(colour.g,colour.b)))/max(.001,max(colour.r,max(colour.g,colour.b)));
 // The neutral ice region is authored partial-dye policy, not a recovered _m map.
 if(use_hue && (!partial_hue || saturation<.4)){
  float value=pow(clamp(max(colour.r,max(colour.g,colour.b)),0.,1.),1./2.2);
  colour=texture(hue_palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(lightness*2.,.4,1.3);
 }
 ALBEDO=alpha_probe ? vec3(.25,.8,.4) : colour*albedo_gain;ROUGHNESS=clamp(.86+(lightness-.5)*.06,.80,.92);
 METALLIC=0.;SPECULAR=.24;
 // Source UV/alpha stays unwarped even when RGB eye landmarks are registered.
 ALPHA=use_source_alpha ? texture(source_alpha_texture,UV).a : 1.;
 ALPHA_SCISSOR_THRESHOLD=.12;
}
