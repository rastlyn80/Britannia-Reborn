shader_type spatial;
render_mode cull_disabled;
uniform vec4 detail_rect = vec4(-1.0);
varying vec2 map_at;
void vertex(){ map_at = VERTEX.xz; }
void fragment(){
 if (map_at.x>=detail_rect.x && map_at.y>=detail_rect.y && map_at.x<detail_rect.z && map_at.y<detail_rect.w) discard;
 ALBEDO=COLOR.rgb; ROUGHNESS=0.94;
}
