shader_type spatial;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D hue_palette : source_color, filter_nearest, repeat_disable;
uniform bool use_hue=false;
uniform bool partial_hue=false;
uniform bool use_normal=false;
uniform float normal_strength=.65;
void fragment(){
    vec3 colour=texture(albedo_texture,UV).rgb;
    bool bark=colour.r>colour.g*1.08 && colour.g>colour.b*1.08;
    if(use_hue && (!partial_hue || bark)){
        float value=max(colour.r,max(colour.g,colour.b));
        float index=floor(pow(clamp(value,0.,1.),1./2.2)*31.);
        colour=texture(hue_palette,vec2((index+.5)/32.,.5)).rgb*mix(.65,1.1,clamp(value*2.,0.,1.));
    }
    ALBEDO=colour;ROUGHNESS=.9;METALLIC=0.;SPECULAR=.15;
    if(use_normal){NORMAL_MAP=texture(normal_texture,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
}
