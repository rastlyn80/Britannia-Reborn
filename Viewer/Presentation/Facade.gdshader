shader_type spatial;
uniform vec2 source_origin=vec2(0.0);
render_mode cull_disabled;
#include "res://Presentation/SurfaceNoise.gdshaderinc"
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 palette : source_color;
uniform bool wood=false;
uniform bool masonry=false;
uniform bool double_sided=false;
uniform bool open_caps=false;
varying vec3 world_position;
// Box pieces are centred, so |VERTEX.y| is half their height: recover each
// piece's world-space base and height (also per MultiMesh instance).
varying float piece_base;
varying float piece_height;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+vec3(source_origin.x,0.0,source_origin.y);
 piece_base=(MODEL_MATRIX*vec4(VERTEX.x,-abs(VERTEX.y),VERTEX.z,1.0)).y;
 piece_height=2.0*abs(VERTEX.y)*length(MODEL_MATRIX[1].xyz);
}
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
void fragment(){
 if(!double_sided && !FRONT_FACING){discard;}
 vec3 n=abs((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 if(open_caps && n.y>0.99){discard;}
 vec2 uv=n.x>n.z?world_position.zy:world_position.xy;
 if(n.y>max(n.x,n.z))uv=world_position.xz;
 float broad=surface_fbm(uv*0.7);
 float fine=surface_noise(uv*30.0);
 vec3 source=texture(surface_albedo,uv*surface_scale).rgb;
 float detail=dot(source,vec3(0.2126,0.7152,0.0722));
 float above=(world_position.y-piece_base);
 // Weathering only reads on full-height pieces; sills/lintels stay clean.
 float tall=smoothstep(1.2,1.8,piece_height);
 float damp=tall*(1.0-smoothstep(0.0,0.55+broad*0.35,above));
 float stain=smoothstep(0.52,0.78,surface_fbm(uv*0.18+vec2(3.1,7.7)));
 float streak=tall*smoothstep(0.55,0.95,surface_noise(vec2(uv.x*3.0,uv.y*0.12)))*(1.0-smoothstep(0.0,piece_height,above))*0.6;
 if(wood){
  float grain=surface_fbm(uv*vec2(20.0,0.6));
  ALBEDO=mix(palette.rgb*mix(0.62,1.1,grain),source*palette.rgb*2.0,0.6)*0.82;
  ALBEDO*=1.0-damp*0.35;
  ROUGHNESS=0.78+grain*0.12;
  NORMAL_MAP=texture(surface_normal_map,uv*surface_scale).rgb;
 }else if(masonry){
  ALBEDO=mix(palette.rgb,source*palette.rgb*1.45,0.86);
  // Darken recessed mortar/pitting from the photoscan luminance.
  ALBEDO*=mix(0.72,1.06,smoothstep(0.12,0.55,detail));
  ALBEDO=mix(ALBEDO,ALBEDO*vec3(0.80,0.84,0.78),damp*0.7+stain*0.25);
  ROUGHNESS=0.88+fine*0.08;
  NORMAL_MAP=texture(surface_normal_map,uv*surface_scale).rgb;
 }else{
  // Rough-cast lime render (York close-studded houses): bright white with the
  // photoscanned plaster's own relief, soft tonal drift, soiled toward the base.
  vec3 lime=palette.rgb*mix(vec3(1.0),vec3(1.0,0.96,0.88),smoothstep(0.55,0.8,surface_fbm(world_position.xz*0.025+vec2(11.0,5.0))));
  float tone=clamp((detail-0.45)*1.6+0.5,0.0,1.0);
  ALBEDO=lime*mix(0.88,1.02,tone)*mix(0.95,1.02,broad);
  ALBEDO=mix(ALBEDO,lime*vec3(0.70,0.67,0.60),stain*0.22);
  ALBEDO=mix(ALBEDO,lime*vec3(0.52,0.50,0.45),damp*0.6);
  ALBEDO*=1.0-streak*0.15;
  ROUGHNESS=0.93;
  NORMAL_MAP=texture(surface_normal_map,uv*surface_scale*1.6).rgb;
 }
 NORMAL_MAP_DEPTH=wood?0.9:(masonry?1.0:1.6);
 ROUGHNESS=mix(ROUGHNESS,texture(surface_roughness,uv*surface_scale).r,0.5);
 SPECULAR=0.24;
}
