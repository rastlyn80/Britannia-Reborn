shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
// A dungeon entrance's opening (Underground.gd): the tunnel walls darken with
// depth into a black back wall. The terrain heightfield cannot be hollowed,
// so the opening is drawn pulled toward the camera by `pull` metres: the
// hillside around it never hides it, while a whole mountain
// between the camera and the entrance still does.
uniform float pull=1.4;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 rock_scale=vec2(0.37);
// x: 0 at the mouth, 1 at the back wall.
varying float depth;
varying vec3 local;
void vertex(){
 depth=UV.x;
 local=VERTEX;
 vec4 view=MODELVIEW_MATRIX*vec4(VERTEX,1.0);
 // Every point is depth-tested as if it lay on the mouth's own plane.
 view.xyz+=normalize(-view.xyz)*(pull+max(0.0,-VERTEX.z));
 POSITION=PROJECTION_MATRIX*view;
}
void fragment(){
 vec3 rock=texture(rock_albedo,(local.xy+local.zz)*rock_scale).rgb;
 float light=pow(1.0-clamp(depth,0.0,1.0),2.2)*0.22;
 ALBEDO=rock*light;
}
