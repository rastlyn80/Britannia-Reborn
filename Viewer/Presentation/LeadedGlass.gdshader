shader_type spatial;
render_mode cull_disabled;
// Leaded lights: diamond quarries of slightly uneven dark glass held in lead
// cames, laid out in metres on the window pane itself.
uniform float quarry_size = 0.11;
varying vec2 pane;
float glass_hash(vec2 p) { return fract(sin(dot(p,vec2(41.3,289.1)))*43758.5453); }
void vertex() { pane = VERTEX.xy; }
void fragment() {
 vec2 diamond = vec2(pane.x+pane.y*1.35,pane.x-pane.y*1.35)/quarry_size;
 vec2 cell = abs(fract(diamond)-0.5);
 float width = fwidth(diamond.x)*1.5+0.035;
 float glass = 1.0-smoothstep(0.5-width*2.0,0.5-width,max(cell.x,cell.y));
 float tone = glass_hash(floor(diamond));
 vec3 tint = mix(vec3(0.075,0.095,0.085),vec3(0.13,0.15,0.12),tone);
 ALBEDO = mix(vec3(0.045,0.045,0.043),tint,glass);
 METALLIC = mix(0.55,0.15,glass);
 ROUGHNESS = mix(0.55,0.05+tone*0.12,glass);
 SPECULAR = 0.6;
 ALPHA = mix(1.0,0.72,glass);
}
