shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D body_palette : source_color, filter_nearest;
uniform sampler2D robe_palette : source_color, filter_nearest;
uniform sampler2D hat_palette : source_color, filter_nearest;
uniform sampler2D shoes_palette : source_color, filter_nearest;
uniform bool use_body=false;
uniform bool use_robe=false;
uniform bool use_hat=false;
uniform bool use_shoes=false;
uniform bool robe_present=false;
uniform bool hat_present=false;
uniform bool shoes_present=false;
uniform bool body_partial=false;
uniform bool robe_partial=false;
uniform bool hat_partial=false;
uniform bool shoes_partial=false;
uniform bool show_masks=false;
uniform float detail_strength=.2;
vec3 dye(vec3 rgb,sampler2D palette,bool partial,float neutral){
 if(partial && neutral<.5)return rgb;
 float value=pow(clamp(max(rgb.r,max(rgb.g,rgb.b)),0.,1.),1./2.2);
 return texture(palette,vec2((floor(value*31.)+.5)/32.,.5)).rgb*clamp(dot(rgb,vec3(.2126,.7152,.0722))*2.,.4,1.3);
}
void fragment(){
 vec4 source=texture(albedo_texture,UV);vec3 rgb=source.rgb;float high=max(rgb.r,max(rgb.g,rgb.b));float low=min(rgb.r,min(rgb.g,rgb.b));float neutral=1.-step(.15,(high-low)/max(.001,high));
 vec3 colour=use_body ? dye(rgb,body_palette,body_partial,neutral) : rgb;
 float robe=clamp(COLOR.r,0.,1.);float hat=clamp(COLOR.g,0.,1.)*(1.-smoothstep(.18,.35,high));float shoes=clamp(COLOR.b,0.,1.);
 if(robe_present)colour=mix(colour,use_robe ? dye(rgb,robe_palette,robe_partial,neutral) : rgb,robe);
 if(hat_present)colour=mix(colour,use_hat ? dye(rgb,hat_palette,hat_partial,neutral) : rgb,hat);
 if(shoes_present)colour=mix(colour,use_shoes ? dye(rgb,shoes_palette,shoes_partial,neutral) : rgb,shoes);
 float grain=sin(UV.x*2600.)*sin(UV.y*2700.);NORMAL_MAP=normalize(vec3(cos(UV.x*2600.)*.08,cos(UV.y*2700.)*.08,1./max(.001,detail_strength)))*.5+.5;
 ALBEDO=show_masks ? vec3(robe,hat,shoes) : colour*(.72+grain*.006);ROUGHNESS=mix(.8,.88,robe);METALLIC=0.;SPECULAR=.23;
}
