shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Ground decal from a photoscanned surface (Art/Surfaces, CC0 Poly Haven):
// world-space texture, an irregular procedural outline per tile ("coverage"
// 0..1, edge noise) and optional speckle (flour, scattered dirt). Wet decals
// (blood) are darker and glossier.
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 surface_scale = vec2(0.5);
uniform vec4 tint : source_color = vec4(1.0);
uniform float coverage = 0.7;
uniform float speckle = 0.0;
uniform float square = 0.0;
uniform float roughness = 0.9;
uniform float seed = 0.0;
varying vec3 world_position;

float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7))+seed*17.0)*43758.5453); }
float noise(vec2 p){
	vec2 i=floor(p), f=fract(p);
	vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);
}
float fbm(vec2 p){ return noise(p)*0.55+noise(p*2.1)*0.3+noise(p*4.3)*0.15; }

void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }

void fragment(){
	vec2 local=UV*2.0-1.0;
	// Outline: a blob (or, for full tiles, a soft square) with noisy edges.
	float radial=mix(length(local),max(abs(local.x),abs(local.y)),square);
	float edge=coverage+(fbm(local*2.6+seed)-0.5)*0.55*(1.0-square*0.7);
	float mask=1.0-smoothstep(edge-0.12,edge+0.02,radial);
	// Speckle: keep scattered specks (flour, dirt) inside the outline.
	float specks=step(1.0-speckle*0.55,noise(local*18.0+seed*3.0));
	mask*=mix(1.0,specks,step(0.001,speckle));
	vec2 uv=world_position.xz*surface_scale;
	vec3 albedo=texture(surface_albedo,uv).rgb*tint.rgb;
	ALBEDO=albedo;
	NORMAL_MAP=texture(surface_normal_map,uv).rgb;
	ROUGHNESS=roughness;
	ALPHA=mask*tint.a;
	if(ALPHA<0.02) discard;
}
