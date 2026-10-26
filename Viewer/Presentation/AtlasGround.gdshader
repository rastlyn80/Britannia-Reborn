shader_type spatial;
render_mode cull_disabled;
uniform vec2 source_origin=vec2(0.0);
uniform vec4 detail_rect = vec4(-1.0);
uniform vec4 detail_rects[16];
uniform int detail_count=0;
varying vec2 map_at;
void vertex(){ map_at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz+source_origin; }
void fragment(){
 if (map_at.x>=detail_rect.x && map_at.y>=detail_rect.y && map_at.x<detail_rect.z && map_at.y<detail_rect.w) discard;
 for(int i=0;i<16;i++){
  if(i>=detail_count)break;
  vec4 r=detail_rects[i];
  if(map_at.x>=r.x && map_at.y>=r.y && map_at.x<r.z && map_at.y<r.w)discard;
 }
 ALBEDO=COLOR.rgb; ROUGHNESS=0.94;
}
