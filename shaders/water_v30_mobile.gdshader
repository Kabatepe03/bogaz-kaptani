shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.006, 0.038, 0.072);
uniform vec3 mid_color : source_color = vec3(0.012, 0.095, 0.145);
uniform vec3 shallow_color : source_color = vec3(0.040, 0.155, 0.185);
uniform vec3 horizon_color : source_color = vec3(0.090, 0.205, 0.245);
uniform vec3 foam_color : source_color = vec3(0.82, 0.88, 0.90);
uniform float wave_height = 0.50;
uniform float sea_state = 0.50;
uniform float time_scale = 0.68;

varying vec2 world_xz;
varying float crest_mix;

float wave_term(vec2 p, vec2 dir, float wavelength, float speed, float phase) {
    float k = 6.2831853 / wavelength;
    return sin(dot(p, normalize(dir)) * k + TIME * time_scale * speed + phase);
}

void vertex() {
    vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
    world_xz = world.xz;
    float h = 0.0;
    h += wave_term(world_xz, vec2(0.96, 0.20), 86.0, 0.52, 0.0) * 0.42;
    h += wave_term(world_xz, vec2(-0.30, 1.0), 43.0, 0.84, 1.6) * 0.25;
    h += wave_term(world_xz, vec2(0.70, 0.66), 22.0, 1.18, 3.1) * 0.12;
    h += wave_term(world_xz, vec2(-0.85, 0.34), 11.5, 1.60, 2.0) * 0.045;
    crest_mix = h;
    VERTEX.y += h * wave_height * (0.58 + sea_state * 0.62);
}

void fragment() {
    vec2 p = world_xz;
    float t = TIME * time_scale;

    vec2 d1 = normalize(vec2(0.96, 0.20));
    vec2 d2 = normalize(vec2(-0.30, 1.0));
    vec2 d3 = normalize(vec2(0.70, 0.66));
    float k1 = 6.2831853 / 86.0;
    float k2 = 6.2831853 / 43.0;
    float k3 = 6.2831853 / 22.0;
    float c1 = cos(dot(p, d1) * k1 + t * 0.52);
    float c2 = cos(dot(p, d2) * k2 + t * 0.84 + 1.6);
    float c3 = cos(dot(p, d3) * k3 + t * 1.18 + 3.1);
    float dhdx = d1.x * k1 * 0.42 * c1 + d2.x * k2 * 0.25 * c2 + d3.x * k3 * 0.12 * c3;
    float dhdz = d1.y * k1 * 0.42 * c1 + d2.y * k2 * 0.25 * c2 + d3.y * k3 * 0.12 * c3;
    vec3 generated_normal = normalize(vec3(-dhdx * 12.0, 1.0, -dhdz * 12.0));
    NORMAL = normalize(mix(NORMAL, generated_normal, 0.82));

    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
    float broad = 0.5 + 0.5 * sin(p.x * 0.0017 + p.y * 0.0011 + t * 0.08);
    float ripple = 0.5 + 0.5 * sin(p.x * 0.018 - p.y * 0.014 + t * 0.72);

    vec3 water = mix(deep_color, mid_color, 0.40 + broad * 0.16);
    water = mix(water, shallow_color, ripple * 0.055);
    water = mix(water, horizon_color, fresnel * 0.22);

    vec3 sun_dir = normalize(vec3(-0.30, 0.93, -0.22));
    vec3 reflected = reflect(-sun_dir, NORMAL);
    float glint = pow(max(dot(reflected, VIEW), 0.0), 96.0) * 0.12;
    float foam = smoothstep(0.74, 0.98, crest_mix) * (0.012 + sea_state * 0.020);

    ALBEDO = mix(water, foam_color, foam);
    ALBEDO += vec3(glint);
    ROUGHNESS = clamp(0.24 + fresnel * 0.15 + ripple * 0.035, 0.22, 0.46);
    METALLIC = 0.0;
    SPECULAR = 0.72;
}
