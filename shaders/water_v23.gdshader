shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec3 deep_color : source_color = vec3(0.004, 0.030, 0.052);
uniform vec3 mid_color : source_color = vec3(0.010, 0.073, 0.105);
uniform vec3 shallow_color : source_color = vec3(0.035, 0.135, 0.148);
uniform vec3 horizon_color : source_color = vec3(0.075, 0.180, 0.205);
uniform vec3 foam_color : source_color = vec3(0.72, 0.78, 0.78);
uniform float wave_height = 0.72;
uniform float sea_state = 0.56;
uniform float time_scale = 0.70;
uniform float refraction_strength = 0.010;

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
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.54;
    mat2 r = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
    for (int i = 0; i < 5; i++) {
        s += noise2(p) * a;
        p = r * p * 2.02 + vec2(7.13, 3.71);
        a *= 0.47;
    }
    return s;
}

float wave(vec2 p, vec2 dir, float wavelength, float speed, float phase) {
    float k = 6.2831853 / wavelength;
    return sin(dot(p, normalize(dir)) * k + TIME * time_scale * speed + phase);
}

float wave_field(vec2 p) {
    float s = 0.0;
    s += wave(p, vec2(0.95, 0.18), 92.0, 0.52, 0.0) * 0.34;
    s += wave(p, vec2(-0.28, 1.0), 51.0, 0.82, 1.7) * 0.22;
    s += wave(p, vec2(0.72, 0.68), 29.0, 1.16, 3.2) * 0.135;
    s += wave(p, vec2(-0.87, 0.36), 16.5, 1.55, 2.1) * 0.078;
    s += wave(p, vec2(0.20, 1.0), 8.6, 2.05, 0.8) * 0.038;
    s += wave(p, vec2(0.98, -0.08), 4.8, 2.75, 4.4) * 0.017;
    return s;
}

float linear_depth(vec2 uv, float depth_sample) {
    vec4 view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, depth_sample, 1.0);
    view.xyz /= max(view.w, 0.00001);
    return -view.z;
}

void vertex() {
    vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_xz = world.xz;
    float broad = wave_field(world_xz);
    float cross = (noise2(world_xz * 0.012 + vec2(TIME * 0.020, -TIME * 0.014)) - 0.5) * 0.14;
    float micro = (noise2(world_xz * 0.050 + vec2(-TIME * 0.035, TIME * 0.028)) - 0.5) * 0.045;
    VERTEX.y += (broad + cross + micro) * wave_height * (0.56 + sea_state * 0.68);
}

void fragment() {
    vec2 p = world_xz;
    float t = TIME * time_scale;
    float eps = 0.62;
    float h0 = wave_field(p) + (fbm(p * 0.044 + vec2(t * 0.10, -t * 0.07)) - 0.5) * 0.31;
    float hx = wave_field(p + vec2(eps, 0.0)) + (fbm((p + vec2(eps, 0.0)) * 0.044 + vec2(t * 0.10, -t * 0.07)) - 0.5) * 0.31;
    float hz = wave_field(p + vec2(0.0, eps)) + (fbm((p + vec2(0.0, eps)) * 0.044 + vec2(t * 0.10, -t * 0.07)) - 0.5) * 0.31;
    vec3 generated_normal = normalize(vec3((h0 - hx) * 0.82, eps, (h0 - hz) * 0.82));
    NORMAL = normalize(mix(NORMAL, generated_normal, 0.86));

    float scene_depth = linear_depth(SCREEN_UV, texture(depth_texture, SCREEN_UV).r);
    float water_depth = max(-VERTEX.z, 0.001);
    float depth_gap = max(scene_depth - water_depth, 0.0);
    float shallow_factor = 1.0 - smoothstep(0.20, 5.5, depth_gap);
    float shore_edge = 1.0 - smoothstep(0.14, 1.45, depth_gap);

    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.6);
    float macro = fbm(p * 0.0020 + vec2(t * 0.009, -t * 0.006));
    float micro = fbm(p * 0.023 + vec2(-t * 0.040, t * 0.030));
    float current_streak = fbm(vec2(p.x * 0.0065 + t * 0.018, p.y * 0.0019 - t * 0.055));

    vec3 water = mix(deep_color, mid_color, 0.30 + macro * 0.34);
    water = mix(water, shallow_color, shallow_factor * 0.48 + fresnel * 0.10);
    water = mix(water, horizon_color, fresnel * 0.16);

    // Depth-aware refraction is strongest in clear shallow water and dies in open channel water.
    vec2 refract_offset = NORMAL.xz * refraction_strength * clamp(depth_gap / 5.0, 0.10, 1.0);
    vec3 refracted = textureLod(screen_texture, clamp(SCREEN_UV + refract_offset, vec2(0.001), vec2(0.999)), 0.0).rgb;
    float refract_mix = shallow_factor * 0.20 * (1.0 - fresnel);
    water = mix(water, refracted * vec3(0.72, 0.88, 0.90), refract_mix);

    vec3 sun_dir = normalize(vec3(-0.34, 0.90, -0.27));
    vec3 reflected = reflect(-sun_dir, NORMAL);
    float sharp_glint = pow(max(dot(reflected, VIEW), 0.0), 190.0) * 0.30;
    float broad_glint = pow(max(dot(reflected, VIEW), 0.0), 48.0) * 0.060;

    float crest = smoothstep(0.69, 0.94, h0) * smoothstep(0.54, 0.86, micro);
    float breaking = shore_edge * smoothstep(0.46, 0.76, micro + abs(h0) * 0.18);
    float streak_foam = smoothstep(0.82, 0.96, current_streak) * sea_state * 0.018;
    float foam = clamp(crest * (0.010 + sea_state * 0.018) + breaking * 0.17 + streak_foam, 0.0, 0.24);

    ALBEDO = mix(water, foam_color, foam);
    ALBEDO += vec3(sharp_glint + broad_glint);
    ROUGHNESS = clamp(0.22 + fresnel * 0.16 + micro * 0.075 + foam * 0.22, 0.20, 0.55);
    METALLIC = 0.0;
    SPECULAR = 0.78;
}
