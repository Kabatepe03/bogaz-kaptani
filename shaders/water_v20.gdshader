shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.005, 0.034, 0.060);
uniform vec3 mid_color : source_color = vec3(0.010, 0.078, 0.118);
uniform vec3 shallow_color : source_color = vec3(0.038, 0.145, 0.170);
uniform vec3 foam_color : source_color = vec3(0.72, 0.79, 0.80);
uniform float wave_height = 0.58;
uniform float sea_state = 0.55;
uniform float time_scale = 0.72;

varying vec2 world_xz;

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
    s += directional_wave(p, vec2(1.0, 0.15), 78.0, 0.58, 0.0) * 0.33;
    s += directional_wave(p, vec2(-0.32, 1.0), 44.0, 0.88, 1.7) * 0.21;
    s += directional_wave(p, vec2(0.71, 0.69), 25.0, 1.18, 3.2) * 0.12;
    s += directional_wave(p, vec2(-0.88, 0.34), 13.8, 1.68, 2.1) * 0.070;
    s += directional_wave(p, vec2(0.17, 1.0), 7.8, 2.05, 0.8) * 0.032;
    return s;
}

void vertex() {
    vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_xz = world.xz;
    float broad = displacement_field(world_xz);
    float irregular = (value_noise(world_xz * 0.008 + vec2(TIME * 0.014, -TIME * 0.010)) - 0.5) * 0.13;
    VERTEX.y += (broad + irregular) * wave_height * (0.56 + sea_state * 0.68);
}

void fragment() {
    vec2 p = world_xz;
    float t = TIME * time_scale;
    float eps = 0.72;
    float h0 = displacement_field(p) + (fbm(p * 0.045 + vec2(t * 0.09, -t * 0.06)) - 0.5) * 0.32;
    float hx = displacement_field(p + vec2(eps, 0.0)) + (fbm((p + vec2(eps, 0.0)) * 0.045 + vec2(t * 0.09, -t * 0.06)) - 0.5) * 0.32;
    float hz = displacement_field(p + vec2(0.0, eps)) + (fbm((p + vec2(0.0, eps)) * 0.045 + vec2(t * 0.09, -t * 0.06)) - 0.5) * 0.32;
    vec3 n = normalize(vec3((h0 - hx) * 0.70, eps, (h0 - hz) * 0.70));
    NORMAL = normalize(mix(NORMAL, n, 0.78));

    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.8);
    float long_variation = fbm(p * 0.0022 + vec2(t * 0.010, -t * 0.007));
    float micro_variation = fbm(p * 0.020 + vec2(-t * 0.035, t * 0.025));
    vec3 water = mix(deep_color, mid_color, 0.34 + long_variation * 0.30);
    water = mix(water, shallow_color, fresnel * 0.17 + micro_variation * 0.030);

    vec3 sun_dir = normalize(vec3(-0.36, 0.88, -0.30));
    vec3 reflected = reflect(-sun_dir, NORMAL);
    float sharp_glint = pow(max(dot(reflected, VIEW), 0.0), 165.0) * 0.34;
    float broad_glint = pow(max(dot(reflected, VIEW), 0.0), 46.0) * 0.055;
    float crest = smoothstep(0.68, 0.93, h0) * smoothstep(0.56, 0.84, micro_variation);
    float foam = crest * (0.018 + sea_state * 0.026);

    ALBEDO = mix(water, foam_color, foam);
    ALBEDO += vec3(sharp_glint + broad_glint);
    ROUGHNESS = clamp(0.24 + fresnel * 0.15 + micro_variation * 0.065, 0.21, 0.50);
    METALLIC = 0.0;
    SPECULAR = 0.74;
}
