shader_type spatial;
render_mode cull_disabled;
uniform vec4 roof_color : source_color = vec4(0.3,0.34,0.4,1.0);
uniform sampler2D kit_texture : source_color, repeat_enable;
uniform bool wood = false;
uniform vec4 ceiling_color : source_color = vec4(0.57,0.45,0.33,1.0);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 tile=UV*vec2(3.5,5.0);
	tile.x+=mod(floor(tile.y),2.0)*0.5;
	vec2 f=fract(tile);
	float edge=min(min(f.x,1.0-f.x),min(f.y,1.0-f.y));
	float bevel=smoothstep(0.01,0.07+length(fwidth(tile)),edge);
	float variation=mix(0.95,1.05,hash(floor(tile)));
	float grain=wood ? 0.97+0.03*sin(UV.x*35.0+sin(UV.y*35.0)*4.0) : 1.0;
	vec3 kit=texture(kit_texture,UV*0.2).rgb;
	ALBEDO=roof_color.rgb*variation*mix(0.88,1.0,bevel)*grain*mix(vec3(1.0),kit*1.7,0.12);
	// Exterior slate belongs outside; the back face is a continuous timber lining.
	if (!FRONT_FACING) {
		float board = fract(UV.x*4.0);
		float joint = smoothstep(0.005,0.025+fwidth(UV.x)*4.0,min(board,1.0-board));
		float timber_grain = 0.97+0.03*sin(UV.y*38.0+sin(UV.x*13.0)*1.5);
		float board_tone = mix(0.96,1.04,hash(vec2(floor(UV.x*4.0),0.0)));
		ALBEDO = ceiling_color.rgb*mix(0.84,1.0,joint)*timber_grain*board_tone;
	}
	ROUGHNESS=0.9;
}
