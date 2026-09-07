shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 marine_white : source_color = vec3(0.79, 0.82, 0.81);
uniform vec3 grime_color : source_color = vec3(0.22, 0.23, 0.20);
uniform vec3 rust_color : source_color = vec3(0.31, 0.105, 0.035);
uniform float weathering = 0.32;

varying vec3 local_pos;

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
    local_pos = VERTEX;
}

void fragment() {
    vec3 p = local_pos;
    float panel_seed = hash21(floor(p.xz * vec2(0.55, 0.10)));
    float fine_seed = hash21(floor(p.zy * vec2(0.37, 0.85)) + 3.7);

    vec3 base = marine_white * (0.94 + panel_seed * 0.055);

    // A working ferry is clean from a distance but gains salt/diesel/grime near the sea surface.
    float waterline_grime = 1.0 - smoothstep(-0.1, 2.45, p.y);
    float splash_band = exp(-pow((p.y - 1.25) / 0.85, 2.0));
    float bow_stern_wet = smoothstep(24.0, 43.0, abs(p.z));
    float grime_noise = 0.35 + 0.65 * hash21(floor(p.xz * vec2(0.42, 0.31)));
    float grime = clamp((waterline_grime * 0.34 + splash_band * (0.08 + bow_stern_wet * 0.10)) * grime_noise * weathering, 0.0, 0.34);
    base = mix(base, grime_color, grime);

    // Narrow vertical rust streaks below scuppers and maintenance points; subtle, not abandoned-ship rust.
    float z_cell = floor((p.z + 44.0) / 5.8);
    float streak_seed = hash11(z_cell * 7.13 + 2.0);
    float z_center = -44.0 + (z_cell + 0.5) * 5.8 + (streak_seed - 0.5) * 1.7;
    float streak_width = 1.0 - smoothstep(0.05, 0.34 + streak_seed * 0.12, abs(p.z - z_center));
    float streak_y = smoothstep(0.75, 3.75, p.y) * (1.0 - smoothstep(3.75, 5.2, p.y));
    float vertical_fade = clamp((4.8 - p.y) / 4.0, 0.0, 1.0);
    float rust_mask = streak_width * streak_y * vertical_fade * step(0.68, streak_seed) * weathering * 0.36;
    base = mix(base, rust_color, rust_mask);

    // Weld/panel rhythm breaks large CG-perfect white surfaces without drawing obvious stripes.
    float longitudinal_seam = 1.0 - smoothstep(0.015, 0.075, abs(fract((p.z + 44.0) / 5.5) - 0.5));
    float horizontal_seam = 1.0 - smoothstep(0.012, 0.055, abs(fract((p.y + 5.0) / 1.48) - 0.5));
    float seam = max(longitudinal_seam * 0.22, horizontal_seam * 0.16) * smoothstep(-0.5, 5.0, p.y);
    base *= 1.0 - seam * 0.10;

    ALBEDO = base;
    ROUGHNESS = clamp(0.40 + fine_seed * 0.10 + grime * 0.32 + rust_mask * 0.22, 0.34, 0.78);
    METALLIC = 0.015;
    SPECULAR = 0.48;
}
