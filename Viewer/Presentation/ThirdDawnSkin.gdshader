shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform bool use_normal_map = true;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.30;
uniform vec4 skin_tone : source_color = vec4(0.72, 0.57, 0.47, 1.0);
uniform float delight_strength : hint_range(0.0, 1.0) = 0.48;
uniform float skin_roughness : hint_range(0.25, 0.9) = 0.58;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float smooth_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
        mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), f.x), f.y);
}
float inside(vec2 p, vec2 lo, vec2 hi) {
    return step(lo.x, p.x) * step(lo.y, p.y) * step(p.x, hi.x) * step(p.y, hi.y);
}
void fragment() {
    vec3 base = texture(albedo_texture, UV).rgb;
    float linen = step(0.755, UV.y) * step(0.25, UV.x);
    float face = inside(UV, vec2(0.50, 0.0), vec2(0.755, 0.245));
    float palms = inside(UV, vec2(0.59, 0.25), vec2(1.0, 0.38));
    float pixel_footprint = max(length(dFdx(UV)), length(dFdy(UV)));
    float detail_visibility = 1.0 - smoothstep(0.0006, 0.003, pixel_footprint);
    float grain = smooth_noise(UV * 550.0) - 0.5;
    // Approximate de-lighting in the material, not an edited source atlas.
    // Coarse luminance is suppressed while pores/facial features remain.
    // This is deliberately bounded: an albedo scan cannot be recovered
    // exactly from the old painted texture.
    vec3 broad = textureLod(albedo_texture, UV, 4.0).rgb;
    vec3 ratio = clamp(base / max(broad, vec3(0.035)), vec3(0.28), vec3(1.7));
    vec3 neutral_skin = skin_tone.rgb * ratio;
    ALBEDO = mix(base, neutral_skin, delight_strength * (1.0 - linen) * (1.0 - face * 0.7));
    METALLIC = 0.0;
    ROUGHNESS = mix(clamp(skin_roughness - face * 0.10 + palms * 0.07
        + grain * 0.045 * detail_visibility, 0.38, 0.76), 0.90, linen);
    SPECULAR = mix(0.34, 0.12, linen);

    // Rebuild a cotangent frame from derivatives: the old glTF body has no
    // authored tangent stream. Never treat diffuse luminance as height.
    vec3 n = normalize(NORMAL);
    vec3 px = dFdx(VERTEX);
    vec3 py = dFdy(VERTEX);
    vec2 ux = dFdx(UV);
    vec2 uy = dFdy(UV);
    float determinant = ux.x * uy.y - ux.y * uy.x;
    if (use_normal_map && abs(determinant) > 0.00000001) {
        vec3 tangent = (px * uy.y - py * ux.y) / determinant;
        vec3 bitangent = (-px * uy.x + py * ux.x) / determinant;
        tangent = normalize(tangent - n * dot(tangent, n));
        bitangent = normalize(bitangent - n * dot(bitangent, n));
        vec3 detail = texture(skin_normal, UV).xyz * 2.0 - 1.0;
        detail.xy *= normal_strength * mix(0.65, 1.0, detail_visibility);
        detail = normalize(detail);
        NORMAL = normalize(tangent * detail.x + bitangent * detail.y + n * detail.z);
    }
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
    SSS_STRENGTH = (1.0 - linen) * 0.12;
#endif
}
