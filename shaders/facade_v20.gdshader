shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 plaster_a : source_color = vec3(0.72, 0.68, 0.59);
uniform vec3 plaster_b : source_color = vec3(0.84, 0.79, 0.68);
uniform vec3 glass_color : source_color = vec3(0.018, 0.055, 0.075);
uniform vec3 roof_color : source_color = vec3(0.30, 0.17, 0.11);

varying vec3 world_pos;
varying vec3 world_nrm;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 n = normalize(world_nrm);
    float seed = hash21(floor(world_pos.xz / 14.0));
    vec3 plaster = mix(plaster_a, plaster_b, seed);
    plaster *= 0.92 + hash21(floor(world_pos.xz / 4.0)) * 0.12;

    if (abs(n.y) > 0.68) {
        float roof_breakup = hash21(floor(world_pos.xz * 0.22));
        ALBEDO = roof_color * (0.82 + roof_breakup * 0.22);
        ROUGHNESS = 0.86;
        METALLIC = 0.0;
        SPECULAR = 0.20;
    } else {
        float along = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
        float floor_phase = fract((world_pos.y + 0.22) / 3.05);
        float bay_phase = fract((along + seed * 1.7) / 2.65);
        float window_y = step(0.25, floor_phase) * (1.0 - step(0.74, floor_phase));
        float window_x = step(0.17, bay_phase) * (1.0 - step(0.78, bay_phase));
        float window_mask = window_y * window_x;

        float frame_y = step(0.22, floor_phase) * (1.0 - step(0.79, floor_phase));
        float frame_x = step(0.13, bay_phase) * (1.0 - step(0.82, bay_phase));
        float frame_mask = max(frame_y * frame_x - window_mask, 0.0);

        float ground_floor = 1.0 - smoothstep(3.0, 4.2, world_pos.y);
        vec3 shop_glass = vec3(0.025, 0.070, 0.082);
        vec3 facade = plaster;
        facade = mix(facade, plaster * 0.55, frame_mask * 0.70);
        facade = mix(facade, glass_color * (0.72 + seed * 0.36), window_mask);
        facade = mix(facade, shop_glass, ground_floor * window_mask * 0.60);

        // Subtle horizontal slab/balcony rhythm prevents large blank wall faces.
        float slab = 1.0 - smoothstep(0.025, 0.075, abs(fract(world_pos.y / 3.05) - 0.04));
        facade = mix(facade, plaster * 0.68, slab * 0.34);

        ALBEDO = facade;
        ROUGHNESS = mix(0.78, 0.18, window_mask);
        METALLIC = window_mask * 0.08;
        SPECULAR = mix(0.28, 0.72, window_mask);
    }
}
