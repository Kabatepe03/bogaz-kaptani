shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.78, 0.84, 0.84);
uniform vec3 water_tint : source_color = vec3(0.14, 0.28, 0.32);
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
    float edge = smoothstep(0.02, 0.32, UV.x) * (1.0 - smoothstep(0.68, 0.98, UV.x));
    float along = 1.0 - smoothstep(0.58, 1.0, UV.y);
    float n1 = noise2(vec2(UV.x * 19.0 + TIME * 0.24, UV.y * 31.0 - TIME * 0.75));
    float n2 = noise2(vec2(UV.x * 47.0 - TIME * 0.18, UV.y * 73.0 + TIME * 0.55));
    float broken = smoothstep(0.44, 0.76, n1 * 0.68 + n2 * 0.32);
    float alpha = edge * along * broken * intensity * COLOR.a;
    if (alpha < 0.015) discard;
    vec3 c = mix(water_tint, foam_color, 0.62 + n2 * 0.27);
    ALBEDO = c;
    ALPHA = min(alpha * 0.46, 0.30);
}
