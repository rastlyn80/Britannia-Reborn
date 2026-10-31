shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
// Ethereal overlay for ghosts (HumanAvatar.set_ghostly): a pale veil over the
// translucent body, brightest at the silhouette, with a slow shimmer rising
// through it.
uniform vec3 veil : source_color = vec3(0.78,0.86,0.96);
uniform vec3 rim : source_color = vec3(0.92,0.97,1.0);
varying vec3 world_position;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float edge=pow(1.0-facing,2.2);
 float shimmer=0.5+0.5*sin(world_position.y*9.0-TIME*2.4+sin(world_position.x*3.0+TIME)*1.5);
 ALBEDO=mix(veil,rim,edge)*(1.0+edge*0.6);
 ALPHA=clamp(0.38+edge*0.55+shimmer*0.08,0.0,0.92);
}
