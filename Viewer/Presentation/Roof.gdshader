shader_type spatial;
render_mode cull_disabled;
uniform vec4 roof_color : source_color = vec4(0.3,0.34,0.4,1.0);
uniform sampler2D kit_texture : source_color, repeat_enable;
uniform bool wood = false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 tile=UV*vec2(2.0,3.0);
	tile.x+=mod(floor(tile.y),2.0)*0.5;
	vec2 f=fract(tile);
	float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	float bevel=smoothstep(0.01,0.07+length(fwidth(tile)),edge);
	float variation=mix(0.95,1.05,hash(floor(tile)));
	float grain=wood ? 0.97+0.03*sin(UV.x*35.0+sin(UV.y*35.0)*4.0) : 1.0;
	vec3 kit=texture(kit_texture,UV*0.2).rgb;
	ALBEDO=roof_color.rgb*variation*mix(0.78,1.0,bevel)*grain*mix(vec3(1.0),kit*1.7,0.12);
	ROUGHNESS=0.9;
}
