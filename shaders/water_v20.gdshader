shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.004, 0.035, 0.060);
uniform vec3 mid_color : source_color = vec3(0.010, 0.085, 0.125);
uniform vec3 surface_color : source_color = vec3(0.035, 0.145, 0.170);
uniform vec3 foam_color : source_color = vec3(0.76, 0.82, 0.82);
uniform float wave_height = 0.62;
uniform float sea_state = 0.58;
uniform float time_scale = 0.72;

varying vec2 world_xz;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0,0.0)), f.x), mix(hash21(i + vec2(0.0,1.0)), hash21(i + vec2(1.0,1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.50;
    mat2 rot = mat2(vec2(0.82,-0.57), vec2(0.57,0.82));
    for (int i = 0; i < 5; i++) {
        s += noise2(p) * a;
        p = rot * p * 2.06 + vec2(5.7, 2.9);
        a *= 0.48;
    }
    return s;
}

float wave(vec2 p, vec2 dir, float wavelength, float speed, float phase) {
    float k = 6.2831853 / wavelength;
    return sin(dot(p, normalize(dir)) * k + TIME * time_scale * speed + phase);
}

float wave_field(vec2 p) {
    float s = 0.0;
    s += wave(p, vec2(1.0,0.13), 82.0, 0.52, 0.0) * 0.34;
    s += wave(p, vec2(-0.28,1.0), 46.0, 0.88, 1.4) * 0.23;
    s += wave(p, vec2(0.69,0.72), 27.0, 1.18, 3.0) * 0.14;
    s += wave(p, vec2(-0.91,0.29), 15.0, 1.72, 2.2) * 0.08;
    s += wave(p, vec2(0.12,1.0), 8.2, 2.30, 0.7) * 0.04;
    return s;
}

float chop_field(vec2 p) {
    float t = TIME * time_scale;
    float a = fbm(p * 0.030 + vec2(t * 0.045, -t * 0.033));
    float b = fbm(p * 0.061 + vec2(-t * 0.068, t * 0.052) + vec2(a * 1.4, -a * 1.1));
    return (a * 0.58 + b * 0.42) - 0.50;
}

void vertex() {
    vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_xz = world.xz;
    float broad = wave_field(world_xz);
    float chop = chop_field(world_xz) * (0.18 + sea_state * 0.22);
    VERTEX.y += (broad + chop) * wave_height * (0.62 + sea_state * 0.68);
}

void fragment() {
    vec2 p = world_xz;
    float eps = 0.48;
    float h0 = wave_field(p) + chop_field(p) * 0.34;
    float hx = wave_field(p + vec2(eps,0.0)) + chop_field(p + vec2(eps,0.0)) * 0.34;
    float hz = wave_field(p + vec2(0.0,eps)) + chop_field(p + vec2(0.0,eps)) * 0.34;
    vec3 water_n = normalize(vec3((h0-hx) * 0.90, eps, (h0-hz) * 0.90));
    NORMAL = normalize(mix(NORMAL, water_n, 0.88));

    float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 4.2);
    float macro = fbm(p * 0.0017 + vec2(TIME * 0.006, -TIME * 0.004));
    float micro = fbm(p * 0.022 + vec2(-TIME * 0.028, TIME * 0.021));
    float current_streak = fbm(vec2(p.x * 0.006 + TIME * 0.013, p.y * 0.0018 - TIME * 0.026));

    vec3 water = mix(deep_color, mid_color, 0.34 + macro * 0.32);
    water = mix(water, surface_color, fresnel * 0.26 + micro * 0.055);
    water *= 0.94 + (current_streak - 0.5) * 0.075;

    vec3 sun_dir = normalize(vec3(-0.38, 0.86, -0.33));
    vec3 reflected = reflect(-sun_dir, NORMAL);
    float sparkle = pow(max(dot(reflected, VIEW), 0.0), 170.0) * 0.50;
    float sheen = pow(max(dot(reflected, VIEW), 0.0), 38.0) * 0.08;

    float crest_height = smoothstep(0.64, 0.96, h0);
    float crest_noise = smoothstep(0.57, 0.82, micro);
    float crest_foam = crest_height * crest_noise * (0.018 + sea_state * 0.052);

    ALBEDO = mix(water, foam_color, crest_foam);
    ALBEDO += vec3(sparkle + sheen);
    ROUGHNESS = clamp(0.17 + micro * 0.11 + fresnel * 0.13, 0.16, 0.42);
    METALLIC = 0.0;
    SPECULAR = 0.90;
}
