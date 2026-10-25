shader_type spatial;
uniform vec2 source_origin=vec2(0.0);
uniform sampler2D surface_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 surface_scale=vec2(1.0);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz+vec3(source_origin.x,0.0,source_origin.y);}
void fragment(){
 vec3 n=abs((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec2 uv=world_position.xz;
 if(n.y<0.5){uv=n.x>n.z?world_position.zy:world_position.xy;}
 ALBEDO=texture(surface_albedo,uv*surface_scale).rgb*vec3(0.78,0.69,0.57);
 NORMAL_MAP=texture(surface_normal_map,uv*surface_scale).rgb;
 NORMAL_MAP_DEPTH=0.18*(1.0-smoothstep(4.0,22.0,length(VERTEX)));
 ROUGHNESS=max(0.88,texture(surface_roughness,uv*surface_scale).r);
 SPECULAR=0.12;
}
