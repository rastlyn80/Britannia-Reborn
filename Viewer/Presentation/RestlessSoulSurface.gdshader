shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D hue_palette : source_color, filter_nearest, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;

void fragment() {
    vec3 source = texture(albedo_texture, UV).rgb;
    float brightest = max(source.r, max(source.g, source.b));
    float darkest = min(source.r, min(source.g, source.b));
    float lightness = dot(source, vec3(0.2126, 0.7152, 0.0722));
    float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
    vec3 colour = mix(vec3(0.14, 0.19, 0.24), vec3(0.78, 0.87, 0.93), sqrt(lightness));
    if (use_hue && (!partial_hue || (brightest - darkest) / max(brightest, 0.001) < 0.08)) {
        float level = floor(pow(brightest, 1.0 / 2.2) * 31.0);
        colour = texture(hue_palette, vec2((level + 0.5) / 32.0, 0.5)).rgb;
    }
    ALBEDO = mix(colour, vec3(0.80, 0.90, 1.0), edge * 0.35);
    ALPHA = clamp(0.38 + 0.25 * sqrt(lightness) + edge * 0.29, 0.0, 0.88);
}
