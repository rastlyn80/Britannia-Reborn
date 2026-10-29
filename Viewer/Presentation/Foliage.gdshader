shader_type spatial;
render_mode cull_disabled;
// Owner-licensed tree surfaces with a see-through clearance around the player.
// Leaves and bark between the camera and the character dissolve (ordered
// dither) inside a soft screen circle around them, so a canopy never hides
// who you are playing; the rest of the tree, and everything behind the
// character, stays whole. The clearance only applies in the main camera's pass
// (clearance_eye), so shadows keep the full tree.
global uniform vec3 clearance_focus;
global uniform vec3 clearance_eye;
global uniform float clearance_radius;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool leaves = false;
uniform float roughness = 0.9;

// A cone from the camera to the player's chest: constant size on screen,
// reaching clearance_radius at the player, with a soft edge.
float clearance(vec3 world, vec3 eye) {
 if (clearance_radius <= 0.0 || distance(eye, clearance_eye) > 0.35) return 1.0;
 vec3 axis = clearance_focus - eye;
 float span = length(axis);
 if (span < 0.01) return 1.0;
 axis /= span;
 float along = dot(world - eye, axis);
 float ahead = span - along; // metres nearer the camera than the player
 if (along <= 0.0 || ahead <= 0.0) return 1.0;
 float radius = clearance_radius * along / span;
 float off = length(world - eye - axis * along);
 float open = 1.0 - smoothstep(radius * 0.55, radius, off);
 return 1.0 - open * smoothstep(0.15, 0.9, ahead);
}

void fragment() {
 vec4 source = texture(albedo_texture, UV);
 float visibility = clearance((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz, CAMERA_POSITION_WORLD);
 // Leaves right at the lens (camera pressed against a crown) thin out softly.
 if (leaves && distance(CAMERA_POSITION_WORLD, clearance_eye) <= 0.35) visibility = min(visibility, smoothstep(0.2, 0.8, length(VERTEX)));
 if (visibility < 0.999) {
  // 4x4 ordered dither: an even screen pattern instead of noisy holes.
  ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
  int index = cell.x + cell.y * 4;
  float bayer[16] = float[](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
  if (visibility <= (bayer[index] + 0.5) / 16.0) discard;
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
