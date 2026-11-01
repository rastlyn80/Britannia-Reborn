shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float phase=0.0;
uniform bool dust=false;
uniform sampler2D hue_palette : source_color,filter_nearest,repeat_disable;
uniform bool use_hue=false;
uniform bool partial_hue=false;
varying vec3 local_point;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
    local_point=VERTEX;
    if(!dust){float seed=COLOR.r*6.283185;VERTEX.x+=sin(phase+UV.y*8.0+seed)*UV.y*UV.y*.055;VERTEX.z+=cos(phase+UV.y*6.0+seed)*UV.y*UV.y*.045;}
}
void fragment(){
    float seed=COLOR.r*6.283185;
    float n=noise(UV*vec2(4.0,7.0)+vec2(sin(phase+seed),cos(phase+seed)*2.0));
    float fine=noise(UV*vec2(13.0,19.0)+vec2(cos(phase)*2.0,sin(phase)*3.0));
    float y=UV.y;
    float x=(UV.x-.5)*2.0-sin(y*8.0+phase+seed)*.24*y;
    float width=pow(max(0.0,1.0-y),.7)*(.7+.3*n);
    float edge=1.0-smoothstep(width*.45,width,abs(x));
    float vertical=smoothstep(.0,.06,y)*(1.0-smoothstep(.85,1.0,y));
    float heat=clamp((1.0-abs(x)/max(width,.001))*(1.0-y)*.85+n*.25+fine*.08,0.0,1.0);
    vec3 colour=mix(vec3(.9,.025,.001),vec3(1.0,.21,.006),smoothstep(.15,.5,heat));
    colour=mix(colour,vec3(1.0,.78,.22),smoothstep(.5,.82,heat));
    colour=mix(colour,vec3(1.0,.96,.75),smoothstep(.88,1.0,heat));
    if(use_hue){
        float intensity=clamp(.15+heat*.85,0.0,1.0);
        float index=floor(pow(clamp(intensity,0.,1.),1./2.2)*31.);
        vec3 dyed=texture(hue_palette,vec2((index+.5)/32.,.5)).rgb*mix(.35,1.1,heat);
        colour=mix(colour,dyed,partial_hue?smoothstep(.35,.70,heat):1.0);
    }
    ALBEDO=colour;EMISSION=colour*(1.0+heat*1.8);ROUGHNESS=1.0;SPECULAR=0.0;
    ALPHA=edge*vertical*(.45+.4*n);
    if(dust){
        vec3 ash=mix(vec3(.12,.105,.09),vec3(.31,.28,.24),n);
        if(use_hue){
            float index=floor(pow(clamp(.25+n*.65,0.0,1.0),1.0/2.2)*31.0);
            vec3 dyed=texture(hue_palette,vec2((index+.5)/32.0,.5)).rgb*(.35+n*.3);
            float mask=partial_hue?1.0-smoothstep(.15,.45,length(local_point.xz)):1.0;
            ash=mix(ash,dyed,mask);
        }
        ALBEDO=ash;EMISSION=vec3(0.0);ALPHA=(.5+n*.35)*(1.0-smoothstep(.05,.65,length(local_point.xz)));
    }
}
