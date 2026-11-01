shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
// Items you can pick up (WorldItems: the server's movable flag 0x20): a warm
// rim that breathes softly, brighter while the mouse is over the item.
uniform float strength = 0.7;
uniform vec3 glow : source_color = vec3(1.0,0.78,0.38);
void fragment(){
 float facing=clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0);
 float rim=pow(1.0-facing,2.5);
 float breathe=0.75+0.25*sin(TIME*2.2);
 ALBEDO=glow*(rim*2.4+0.1)*strength*breathe;
}
