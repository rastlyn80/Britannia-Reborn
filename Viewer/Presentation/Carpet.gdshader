shader_type spatial;
render_mode cull_disabled;
// Woven pile rug from photoscans (CC0 Poly Haven): the damask jacquard's
// figure becomes the dyed field pattern, the carpet scan gives pile and
// fibre relief. Each source tile knows which of its sides are the rug's
// outer edge ("edges": 1 west, 2 east, 4 north, 8 south) and draws
// the guard stripes and border band there, so a rug of any size reads as one
// piece. Field patterns run in world space across tiles.
uniform vec4 base_color : source_color=vec4(0.12,0.18,0.32,1.0);
uniform vec4 border_color : source_color=vec4(0.42,0.12,0.09,1.0);
uniform vec4 motif_color : source_color=vec4(0.70,0.58,0.38,1.0);
uniform sampler2D pattern : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pile : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D pile_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform int edges = 0;
varying vec3 world_position;

void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

float figure(vec2 uv){
	float lum=dot(texture(pattern,uv,0.8).rgb,vec3(0.299,0.587,0.114));
	// source_color decodes to linear: the damask spans ~0.03-0.09 there.
	return smoothstep(0.03,0.085,lum);
}

void fragment(){
	vec2 w=world_position.xz;
	// Field: damask figure at a rug-sized repeat (about 0.75 m).
	float field_figure=figure(w*vec2(1.33,0.88));
	vec3 albedo=mix(base_color.rgb,motif_color.rgb*0.8,field_figure*0.42);
	// Distance from this tile's point to the rug's outer edges.
	float d=10.0;
	if((edges&1)!=0) d=min(d,UV.x);
	if((edges&2)!=0) d=min(d,1.0-UV.x);
	if((edges&4)!=0) d=min(d,UV.y);
	if((edges&8)!=0) d=min(d,1.0-UV.y);
	if(d<0.2){
		float along=(edges&3)!=0&&(d==UV.x||d==1.0-UV.x)?w.y:w.x;
		// Border band: a running figure at a smaller repeat on the border dye.
		float run=figure(vec2(along*2.6,d*2.6+0.37));
		vec3 border=mix(border_color.rgb,motif_color.rgb,run*0.7);
		vec3 guard=motif_color.rgb*0.95;
		albedo=d<0.03?border_color.rgb*0.55:(d<0.045?guard:(d<0.165?border:(d<0.18?guard:albedo)));
	}
	// Pile: the scan's fibre brightness (high-passed, so its own stripes do
	// not show) and slight wear in the walked middle of a rug.
	vec3 fibre=texture(pile,w*1.6).rgb;
	float tuft=dot(fibre,vec3(0.333))/max(dot(textureLod(pile,w*1.6,6.0).rgb,vec3(0.333)),0.02);
	albedo*=mix(0.86,1.12,clamp((tuft-0.6)*0.8,0.0,1.0));
	float wear=smoothstep(0.35,0.0,abs(fract(w.x*0.21+w.y*0.13)-0.5))*0.05;
	ALBEDO=albedo*(1.0+wear);
	NORMAL_MAP=texture(pile_normal,w*1.6).rgb;
	NORMAL_MAP_DEPTH=0.8;
	ROUGHNESS=0.97;
	SPECULAR=0.25;
}
