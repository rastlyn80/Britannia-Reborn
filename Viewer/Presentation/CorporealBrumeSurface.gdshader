shader_type spatial;
render_mode cull_disabled;

uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest;
uniform bool use_hue = false;
uniform bool partial_hue = false;

void fragment() {
    vec4 original = texture(source_atlas, UV);
    float front = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float pulse = 0.5 + 0.5 * sin(UV.x * 29.0 + 1.5 * sin(UV.y * 18.0));
    float core = smoothstep(0.13, 0.97, front) * (0.65 + 0.35 * pulse);
    vec3 tint = mix(vec3(0.018, 0.40, 0.025), vec3(0.035, 0.60, 0.30), core);
    if (use_hue) {
        vec3 dyed = texture(hue_palette, vec2(mix(0.42, 0.92, core), 0.5)).rgb;
        tint = mix(dyed, tint, partial_hue ? core : 0.0);
    }
    ALBEDO = tint * mix(0.35, 0.85, front);
    EMISSION = tint * mix(0.22, 0.48, core);
    ROUGHNESS = 0.42;
    SPECULAR = 0.31;
    ALPHA = original.a;
    ALPHA_SCISSOR_THRESHOLD = 0.12;
}
