shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.72, 0.79, 0.80);
uniform vec3 water_mix : source_color = vec3(0.16, 0.28, 0.33);
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
    across = smoothstep(0.18, 0.92, across);
    float age = clamp(UV.y, 0.0, 1.0);
    float young = smoothstep(0.0, 0.055, age);
    float old_fade = 1.0 - smoothstep(0.38, 0.94, age);

    float coarse = noise2(vec2(UV.x * 14.0 + TIME * 0.08, age * 31.0 - TIME * 0.72));
    float fine = noise2(vec2(UV.x * 43.0 - TIME * 0.12, age * 79.0 + TIME * 0.94));
    float breakup = coarse * 0.68 + fine * 0.32;
    float flecks = smoothstep(0.56, 0.82, breakup);
    float strip_kind = clamp(COLOR.r, 0.0, 1.0);
    float density = mix(0.52, 0.76, strip_kind);
    float mask = smoothstep(density - 0.17, density + 0.11, breakup);

    float alpha = across * young * old_fade * mask * COLOR.a * strength;
    alpha *= mix(0.42, 0.78, strip_kind);
    alpha *= 0.28 + flecks * 0.72;
    if (alpha < 0.012) {
        discard;
    }

    vec3 foam = mix(water_mix, foam_color, 0.62 + flecks * 0.28);
    ALBEDO = foam;
    ALPHA = min(alpha * 0.42, 0.24);
}
