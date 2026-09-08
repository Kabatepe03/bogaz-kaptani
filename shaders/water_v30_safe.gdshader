shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.010, 0.075, 0.115);
uniform vec3 mid_color : source_color = vec3(0.018, 0.125, 0.175);
uniform vec3 shallow_color : source_color = vec3(0.040, 0.180, 0.220);
uniform vec3 horizon_color : source_color = vec3(0.090, 0.245, 0.310);
uniform float wave_height = 0.30;
uniform float sea_state = 0.48;
uniform float time_scale = 0.75;

varying vec2 sea_pos;

void vertex() {
    sea_pos = VERTEX.xz;
    float t = TIME * time_scale;
    float w = 0.0;
    w += sin(VERTEX.x * 0.050 + VERTEX.z * 0.012 + t * 0.72) * 0.46;
    w += sin(VERTEX.x * -0.021 + VERTEX.z * 0.066 + t * 0.98 + 1.7) * 0.27;
    w += sin(VERTEX.x * 0.110 + VERTEX.z * -0.045 + t * 1.42 + 3.1) * 0.12;
    VERTEX.y += w * wave_height * (0.80 + sea_state * 0.24);
}

void fragment() {
    float t = TIME * time_scale;
    float ripple = sin(sea_pos.x * 0.075 + sea_pos.y * 0.032 + t) * 0.5 + 0.5;
    float cross = sin(sea_pos.x * -0.031 + sea_pos.y * 0.095 + t * 1.23 + 2.1) * 0.5 + 0.5;
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
    vec3 base = mix(deep_color, mid_color, 0.30 + ripple * 0.14 + cross * 0.06);
    base = mix(base, shallow_color, cross * 0.05);
    base = mix(base, horizon_color, fresnel * 0.24);
    ALBEDO = base;
    ROUGHNESS = 0.44 + ripple * 0.07;
    METALLIC = 0.0;
    SPECULAR = 0.34;
}
