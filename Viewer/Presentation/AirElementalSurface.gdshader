shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform float phase=0.0;
uniform bool dust=false;
uniform sampler2D hue_palette : source_color, filter_nearest, repeat_disable;
uniform bool use_hue=false;
uniform bool partial_hue=false;
varying vec3 wind_position;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){
    vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){
    wind_position=VERTEX;
    float lower=dust ? 0.0 : COLOR.r;
    float a=lower*(VERTEX.y*10.0+phase*2.0);
    VERTEX.xz=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*VERTEX.xz;
    NORMAL.xz=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*NORMAL.xz;
    float billow=sin(VERTEX.y*19.0-phase*3.0+VERTEX.x*7.0)*sin(VERTEX.z*15.0+phase);
    if(!dust) VERTEX+=NORMAL*billow*.025*smoothstep(.02,.25,VERTEX.y);
}
void fragment(){
    vec3 p=wind_position*7.0+vec3(sin(phase)*.3,cos(phase)*.7,sin(phase*2.0)*.1);
    float density=noise3(p)*.6+noise3(p*2.03)*.28+noise3(p*4.07)*.12;
    float lower=1.0-smoothstep(.65,1.15,wind_position.y);
    float spiral=sin(wind_position.y*35.0-atan(wind_position.z,wind_position.x)*3.0-phase*5.0)*.5+.5;
    float edge=pow(max(0.0,dot(normalize(NORMAL),normalize(VIEW))),1.4);
    vec3 colour=mix(vec3(.26,.30,.35),vec3(.81,.84,.89),density);
    if(use_hue && (!partial_hue || density>.55)) colour=texture(hue_palette,vec2(clamp(.28+density*.6,0.0,1.0),.5)).rgb;
    ALBEDO=colour;ROUGHNESS=.98;SPECULAR=.0;METALLIC=0.0;
    ALPHA=clamp((.15+density*.50)*edge*mix(1.0,.6+spiral*.4,lower),0.0,.72);
    if(dust) ALPHA=(.2+density*.3)*(1.0-smoothstep(.05,.65,length(wind_position.xz)));
}
