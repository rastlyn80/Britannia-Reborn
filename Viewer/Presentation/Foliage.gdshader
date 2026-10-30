shader_type spatial;
render_mode cull_disabled;
// Owner-licensed tree surfaces. A tree whose crown would hide the player, or
// that the camera is pushed into, drops its leaves as a whole (a soft ordered
// dither) and keeps its trunk and branches, so there is no see-through hole:
// the tree simply stands bare until the view is clear again. Each tree fades
// by its own origin (MODEL_MATRIX, per instance in a MultiMesh), so the crown
// goes uniformly. Only the main camera's pass (clearance_eye) fades; shadows
// keep the full tree.
global uniform vec3 clearance_focus;
global uniform vec3 clearance_eye;
global uniform float clearance_radius;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool leaves = false;
uniform float roughness = 0.9;
varying float crown;

// 1 = full crown, 0 = bare, from where the tree stands against the camera and
// the player.
float crown_visibility(vec3 tree, vec3 eye) {
 if (clearance_radius <= 0.0 || distance(eye, clearance_eye) > 0.35) return 1.0;
 vec2 t = tree.xz;
 vec2 e = eye.xz;
 vec2 f = clearance_focus.xz;
 // The camera inside or right beside the crown.
 float near_lens = smoothstep(2.4, 3.8, distance(t, e));
 // The crown on the line of sight from the camera to the player, up to just
 // past the player (a tree the player stands under also hides them).
 vec2 axis = f - e;
 float span = length(axis);
 if (span < 0.05) return near_lens;
 axis /= span;
 float along = dot(t - e, axis);
 float off = length(t - e - axis * along);
 float between = step(0.0, along) * (1.0 - smoothstep(span + 0.8, span + 1.8, along));
 float in_line = 1.0 - between * (1.0 - smoothstep(clearance_radius * 1.3, clearance_radius * 2.1, off));
 return min(near_lens, in_line);
}

void vertex() {
 crown = leaves ? crown_visibility((MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz, CAMERA_POSITION_WORLD) : 1.0;
}

void fragment() {
 vec4 source = texture(albedo_texture, UV);
 if (leaves && crown < 0.999) {
  // 4x4 ordered dither: an even fade over the whole crown, no noisy holes.
  ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
  int index = cell.x + cell.y * 4;
  float bayer[16] = float[](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
  if (crown <= (bayer[index] + 0.5) / 16.0) discard;
 }
 ALBEDO = source.rgb;
 ROUGHNESS = roughness;
 if (leaves) {
  ALPHA = source.a;
  ALPHA_SCISSOR_THRESHOLD = 0.45;
  ALPHA_ANTIALIASING_EDGE = 0.3;
  ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_texture, 0));
 }
}
