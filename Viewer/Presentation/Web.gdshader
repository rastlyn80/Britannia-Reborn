shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;
// Spider web: radial threads and a spiral of capture silk, fading at the edge.
uniform float seed = 0.0;
uniform vec4 silk : source_color = vec4(0.92,0.92,0.88,0.75);
void fragment(){
	vec2 p = UV*2.0-1.0;
	float r = length(p);
	float a = atan(p.y,p.x)+seed;
	float spokes = 1.0-smoothstep(0.0,0.045,abs(sin(a*7.0))*r);
	float spiral = 1.0-smoothstep(0.0,0.06,abs(fract(r*9.0-a*0.14)-0.5)*2.0*0.25);
	float web = max(spokes,spiral*step(0.12,r))*(1.0-smoothstep(0.82,1.0,r));
	ALBEDO = silk.rgb;
	ALPHA = web*silk.a;
	if(ALPHA<0.03) discard;
}
