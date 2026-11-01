shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A soft halo over an item you can pick up (WorldItems), so loot on the ground
// is easy to spot however small or half-sunk its model is. It always faces
// the camera and is drawn pulled toward it, so the ground right under it never
// hides it while a wall between you and the item still does.
uniform vec3 glow : source_color = vec3(1.0,0.8,0.42);
uniform float strength = 0.75;
uniform float pull = 0.6;
varying vec2 local;
void vertex(){
 local = UV-vec2(0.5);
 // Billboard around the node's origin.
 vec4 centre = MODELVIEW_MATRIX*vec4(0.0,0.0,0.0,1.0);
 vec4 view = centre+vec4(VERTEX.xy,0.0,0.0);
 view.xyz += normalize(-centre.xyz)*pull;
 POSITION = PROJECTION_MATRIX*view;
}
void fragment(){
 float r = length(local)*2.0;
 float halo = pow(clamp(1.0-r,0.0,1.0),2.2);
 float core = pow(clamp(1.0-r*2.2,0.0,1.0),3.0);
 float breathe = 0.7+0.3*sin(TIME*2.0);
 ALBEDO = glow*(halo*0.8+core*1.2)*strength*breathe;
}
