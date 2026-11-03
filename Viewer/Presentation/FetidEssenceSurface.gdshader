shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 energy_colour : source_color = vec4(0.42, 0.69, 0.20, 1.0);
uniform float phase = 0.0;
uniform bool core = false;
uniform float density = 1.0;
uniform sampler2D hue_palette : source_color, filter_linear, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;
varying vec3 cloud_position;

void vertex() {
    cloud_position = VERTEX;
}

void fragment() {
    vec3 p = cloud_position * 19.0;
    float eddy = sin(p.x + 1.3 * sin(p.y + phase)) * sin(p.z - phase);
    float curl = sin(dot(p, vec3(1.4, -0.7, 1.1)) + eddy * 2.0 + phase);
    float billow = smoothstep(-0.72, 0.64, 0.56 * eddy + 0.44 * curl);
    float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float falloff = core ? 1.0 : pow(max(0.0, 1.0 - UV.y), 0.65);
    vec3 tint = energy_colour.rgb;
    if (use_hue && (!partial_hue || !core)) {
        tint = texture(hue_palette, vec2(mix(0.48, 0.86, billow), 0.5)).rgb;
    }
    ALBEDO = tint * mix(0.44, 1.16, billow);
    EMISSION = tint * (0.11 + 0.34 * billow);
    ALPHA = density * falloff * pow(face, 1.3) * mix(0.12, 0.66, billow);
}
