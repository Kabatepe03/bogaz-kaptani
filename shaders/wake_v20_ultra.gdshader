shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.68, 0.76, 0.78);
uniform vec3 water_mix : source_color = vec3(0.045, 0.12, 0.15);
uniform float strength = 0.55;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 37.5);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    float across = 1.0 - abs(UV.x * 2.0 - 1.0);
    across = smoothstep(0.16, 0.88, across);
    float age = clamp(UV.y, 0.0, 1.0);
    float young = smoothstep(0.0, 0.045, age);
    float old_fade = 1.0 - smoothstep(0.31, 0.92, age);

    float coarse = noise2(vec2(UV.x * 18.0 + TIME * 0.10, age * 36.0 - TIME * 0.79));
    float fine = noise2(vec2(UV.x * 57.0 - TIME * 0.14, age * 91.0 + TIME * 1.08));
    float cells = noise2(vec2(UV.x * 113.0 + TIME * 0.05, age * 143.0 - TIME * 0.52));
    float breakup = coarse * 0.56 + fine * 0.30 + cells * 0.14;
    float flecks = smoothstep(0.62, 0.86, breakup);
    float strip_kind = clamp(COLOR.r, 0.0, 1.0);
    float threshold = mix(0.64, 0.58, strip_kind);
    float mask = smoothstep(threshold - 0.08, threshold + 0.10, breakup);

    float alpha = across * young * old_fade * mask * COLOR.a * strength;
    alpha *= mix(0.26, 0.46, strip_kind);
    alpha *= 0.20 + flecks * 0.80;
    if (alpha < 0.010) {
        discard;
    }

    vec3 foam = mix(water_mix, foam_color, 0.42 + flecks * 0.36);
    ALBEDO = foam;
    ALPHA = min(alpha * 0.26, 0.105);
}
