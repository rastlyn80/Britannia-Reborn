shader_type spatial;
render_mode cull_disabled;
uniform vec4 palette : source_color=vec4(1.0);
uniform sampler2D surface_albedo : source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
uniform bool has_texture=false;
uniform bool local_uv=false;
uniform vec4 detail_rects[16];
uniform int detail_count=0;
varying vec3 world_at;
varying vec2 owner_chunk;
void vertex(){world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;owner_chunk=local_uv?INSTANCE_CUSTOM.xy:UV2;}
void fragment(){
 for(int i=0;i<16;i++){
  if(i>=detail_count)break;
  vec4 r=detail_rects[i];
  if(owner_chunk.x>=r.x && owner_chunk.y>=r.y && owner_chunk.x<r.z && owner_chunk.y<r.w)discard;
 }
 vec3 n=abs((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec2 uv=world_at.xz;
 if(n.y<0.5)uv=n.x>n.z?world_at.zy:world_at.xy;
 ALBEDO=palette.rgb;
 if(local_uv)uv=UV;
 if(has_texture)ALBEDO*=mix(vec3(0.75),texture(surface_albedo,uv*surface_scale).rgb*2.0,0.65);
 ALPHA=1.0;
 ALPHA_SCISSOR_THRESHOLD=0.4;
 if(local_uv && has_texture)ALPHA=texture(surface_albedo,uv*surface_scale).a;
 ROUGHNESS=0.92;
}
