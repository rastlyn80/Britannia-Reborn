shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 energy_colour : source_color = vec4(0.24,0.48,1.0,1.0);
uniform float phase = 0.0;
uniform bool core = false;
uniform float density = 1.0;
uniform sampler2D hue_palette : source_color, filter_linear, repeat_disable;
uniform bool use_hue = false;
uniform bool partial_hue = false;
void fragment() {
    float edge = abs(dot(normalize(NORMAL),normalize(VIEW)));
    float wave = 0.82 + 0.18*sin(phase*3.0 + UV.x*18.0 + UV.y*7.0);
    float striation = 0.7 + 0.3*pow(sin(UV.x*37.7+UV.y*13.0-phase*2.0),2.0);
    float gain = core ? pow(edge,2.0) : pow(max(0.0,1.0-UV.y),1.4)*pow(edge,2.1)*wave*striation;
    vec3 tint = mix(energy_colour.rgb,vec3(0.95,0.98,1.0),core ? edge*0.95 : pow(1.0-UV.y,5.0));
    if (use_hue && (!partial_hue || !core)) {
        float brightness=clamp(max(tint.r,max(tint.g,tint.b)),0.0,1.0);
        tint=texture(hue_palette,vec2(brightness,0.5)).rgb;
    }
    ALBEDO=tint*(core ? 2.4 : 1.4);
    EMISSION=tint*(core ? 3.0 : 1.4);
    ALPHA = gain*density*(core ? 0.95 : 0.52);
}
