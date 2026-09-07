shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.006, 0.045, 0.075);
uniform vec3 mid_color : source_color = vec3(0.015, 0.105, 0.145);
uniform vec3 shallow_color : source_color = vec3(0.045, 0.185, 0.205);
uniform vec3 foam_color : source_color = vec3(0.78, 0.84, 0.84);
uniform float wave_height = 0.58;
uniform float sea_state = 0.55;
uniform float time_scale = 0.72;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.52;
    mat2 r = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
    for (int i = 0; i < 4; i++) {
        s += value_noise(p) * a;
        p = r * p * 2.03 + vec2(7.13, 3.71);
        a *= 0.48;
    }
    return s;
}

float directional_wave(vec2 p, vec2 dir, float wavelength, float speed, float phase) {
    float k = 6.2831853 / wavelength;
    return sin(dot(p, normalize(dir)) * k + TIME * time_scale * speed + phase);
}

float displacement_field(vec2 p) {
    float s = 0.0;
    s += directional_wave(p, vec2(1.0, 0.15), 74.0, 0.60, 0.0) * 0.34;
    s += directional_wave(p, vec2(-0.32, 1.0), 42.0, 0.92, 1.7) * 0.22;
    s += directional_wave(p, vec2(0.71, 0.69), 24.0, 1.24, 3.2) * 0.13;
    s += directional_wave(p, vec2(-0.88, 0.34), 13.5, 1.75, 2.1) * 0.075;
    s += directional_wave(p, vec2(0.17, 1.0), 7.5, 2.20, 0.8) * 0.035;
    return s;
}

void vertex() {
    vec2 worldish = UV * 15500.0;
    float broad = displacement_field(worldish);
    float irregular = (value_noise(worldish * 0.008 + vec2(TIME * 0.015, -TIME * 0.010)) - 0.5) * 0.14;
    VERTEX.y += (broad + irregular) * wave_height * (0.58 + sea_state * 0.70);
}

void fragment() {
    vec2 p = UV * 15500.0;
    float t = TIME * time_scale;

    // Analytic-looking normal breakup from several independent scales. The low-frequency field
    // keeps long Dardanelles swells readable while the FBM stops the surface from looking tiled.
    float eps = 0.72;
    float h0 = displacement_field(p) + (fbm(p * 0.045 + vec2(t * 0.09, -t * 0.06)) - 0.5) * 0.34;
    float hx = displacement_field(p + vec2(eps, 0.0)) + (fbm((p + vec2(eps, 0.0)) * 0.045 + vec2(t * 0.09, -t * 0.06)) - 0.5) * 0.34;
    float hz = displacement_field(p + vec2(0.0, eps)) + (fbm((p + vec2(0.0, eps)) * 0.045 + vec2(t * 0.09, -t * 0.06)) - 0.5) * 0.34;
    vec3 n = normalize(vec3((h0 - hx) * 0.72, eps, (h0 - hz) * 0.72));
    NORMAL = normalize(mix(NORMAL, n, 0.78));

    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.6);
    float long_variation = fbm(p * 0.0022 + vec2(t * 0.010, -t * 0.007));
    float micro_variation = fbm(p * 0.020 + vec2(-t * 0.035, t * 0.025));
    vec3 water = mix(deep_color, mid_color, 0.38 + long_variation * 0.28);
    water = mix(water, shallow_color, fresnel * 0.23 + micro_variation * 0.045);

    vec3 sun_dir = normalize(vec3(-0.36, 0.88, -0.30));
    vec3 reflected = reflect(-sun_dir, NORMAL);
    float sharp_glint = pow(max(dot(reflected, VIEW), 0.0), 145.0) * 0.62;
    float broad_glint = pow(max(dot(reflected, VIEW), 0.0), 34.0) * 0.10;

    // Tiny crest breakup only: never produces the giant white carpet blobs from older builds.
    float crest = smoothstep(0.63, 0.90, h0) * smoothstep(0.52, 0.82, micro_variation);
    float foam = crest * (0.025 + sea_state * 0.035);

    ALBEDO = mix(water, foam_color, foam);
    ALBEDO += vec3(sharp_glint + broad_glint);
    ROUGHNESS = clamp(0.20 + fresnel * 0.16 + micro_variation * 0.07, 0.18, 0.48);
    METALLIC = 0.0;
    SPECULAR = 0.86;
}
