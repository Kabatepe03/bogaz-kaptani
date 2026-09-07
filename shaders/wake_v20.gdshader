shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_alpha_prepass, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.84, 0.90, 0.91);
uniform float strength = 0.82;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.5);
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
    across = smoothstep(0.0, 0.72, across);
    float age = clamp(UV.y, 0.0, 1.0);
    float young = smoothstep(0.0, 0.035, age);
    float old_fade = 1.0 - smoothstep(0.58, 1.0, age);
    float breakup = noise2(vec2(UV.x * 19.0 + TIME * 0.10, age * 44.0 - TIME * 1.25));
    float streak = sin(UV.x * 31.0 + age * 67.0 - TIME * 2.1) * 0.5 + 0.5;
    float foam = smoothstep(0.34, 0.72, breakup * 0.72 + streak * 0.28);
    float alpha = across * young * old_fade * foam * strength;
    ALBEDO = foam_color;
    ALPHA = alpha * 0.58;
}
