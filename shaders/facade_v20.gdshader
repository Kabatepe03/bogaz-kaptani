shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 plaster_a : source_color = vec3(0.88, 0.86, 0.80);
uniform vec3 plaster_b : source_color = vec3(0.76, 0.79, 0.77);
uniform vec3 plaster_c : source_color = vec3(0.86, 0.70, 0.60);
uniform vec3 plaster_d : source_color = vec3(0.70, 0.80, 0.82);
uniform vec3 plaster_e : source_color = vec3(0.87, 0.82, 0.66);
uniform vec3 glass_color : source_color = vec3(0.012, 0.045, 0.065);
uniform vec3 roof_color : source_color = vec3(0.38, 0.16, 0.085);

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
    float seed = hash21(floor(world_pos.xz / 12.0));
    float seed2 = hash21(floor(world_pos.zx / 25.0) + vec2(5.2, 9.1));
    vec3 plaster = plaster_a;
    if (seed < 0.18) plaster = plaster_b;
    else if (seed < 0.40) plaster = plaster_a;
    else if (seed < 0.61) plaster = plaster_c;
    else if (seed < 0.82) plaster = plaster_d;
    else plaster = plaster_e;
    plaster *= 0.92 + seed2 * 0.13;

    if (abs(n.y) > 0.68) {
        // Tile-scale breakup makes pitched roofs read as terracotta rather than flat orange slabs.
        vec2 tile_uv = world_pos.xz * vec2(0.38, 0.58);
        float row = floor(tile_uv.y);
        float tile = fract(tile_uv.x + mod(row, 2.0) * 0.5);
        float grout = smoothstep(0.03, 0.09, min(tile, 1.0 - tile));
        float tile_noise = hash21(floor(tile_uv));
        vec3 roof = roof_color * (0.74 + tile_noise * 0.32);
        roof *= mix(0.68, 1.0, grout);
        ALBEDO = roof;
        ROUGHNESS = 0.88;
        METALLIC = 0.0;
        SPECULAR = 0.18;
    } else {
        float along = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
        float floor_phase = fract((world_pos.y + 0.20) / 3.05);
        float bay_phase = fract((along + seed * 1.7) / 2.72);
        float window_y = step(0.24, floor_phase) * (1.0 - step(0.73, floor_phase));
        float window_x = step(0.17, bay_phase) * (1.0 - step(0.78, bay_phase));
        float window_mask = window_y * window_x;

        float mullion_x = 1.0 - smoothstep(0.015, 0.045, abs(bay_phase - 0.50));
        float sill = 1.0 - smoothstep(0.018, 0.055, abs(floor_phase - 0.22));
        float slab = 1.0 - smoothstep(0.018, 0.060, abs(fract(world_pos.y / 3.05) - 0.045));
        float balcony_shadow = smoothstep(0.76, 0.91, floor_phase) * smoothstep(0.10, 0.22, bay_phase) * (1.0 - smoothstep(0.78, 0.91, bay_phase));

        float ground_floor = 1.0 - smoothstep(3.2, 4.5, world_pos.y);
        vec3 facade = plaster;
        facade *= 1.0 - balcony_shadow * 0.13;
        facade = mix(facade, plaster * 0.67, slab * 0.42 + sill * 0.16);
        facade = mix(facade, glass_color * (0.70 + seed * 0.34), window_mask);
        facade = mix(facade, vec3(0.020,0.060,0.072), ground_floor * window_mask * 0.70);
        facade = mix(facade, vec3(0.17,0.18,0.18), mullion_x * window_mask * 0.42);

        // Mediterranean lower-wall weathering and pavement splash dirt.
        float grime = (1.0 - smoothstep(0.45, 2.4, world_pos.y)) * (0.08 + seed2 * 0.10);
        facade *= 1.0 - grime;

        ALBEDO = facade;
        ROUGHNESS = mix(0.80, 0.16, window_mask);
        METALLIC = window_mask * 0.07;
        SPECULAR = mix(0.24, 0.76, window_mask);
    }
}
