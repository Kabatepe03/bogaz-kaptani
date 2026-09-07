shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.70, 0.78, 0.79);
uniform vec3 water_tint : source_color = vec3(0.045, 0.12, 0.15);
uniform float intensity = 0.62;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 31.3);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x), mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}

void fragment() {
    float edge = smoothstep(0.03, 0.34, UV.x) * (1.0 - smoothstep(0.66, 0.97, UV.x));
    float along = 1.0 - smoothstep(0.50, 1.0, UV.y);
    float n1 = noise2(vec2(UV.x * 23.0 + TIME * 0.26, UV.y * 39.0 - TIME * 0.82));
    float n2 = noise2(vec2(UV.x * 61.0 - TIME * 0.20, UV.y * 87.0 + TIME * 0.61));
    float n3 = noise2(vec2(UV.x * 107.0 + TIME * 0.11, UV.y * 141.0 - TIME * 0.39));
    float broken = smoothstep(0.56, 0.80, n1 * 0.55 + n2 * 0.31 + n3 * 0.14);
    float alpha = edge * along * broken * intensity * COLOR.a;
    if (alpha < 0.012) discard;
    vec3 c = mix(water_tint, foam_color, 0.45 + n2 * 0.34);
    ALBEDO = c;
    ALPHA = min(alpha * 0.26, 0.115);
}
