shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_rough : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_rough : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying vec3 world_nrm;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1,0)), f.x), mix(hash21(i + vec2(0,1)), hash21(i + vec2(1,1)), f.x), f.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec2 uv_a = world_pos.xz * 0.020;
    vec2 uv_b = (world_pos.xz + vec2(world_pos.z, -world_pos.x) * 0.17) * 0.0063;
    float macro = noise2(world_pos.xz * 0.00072);
    float detail = noise2(world_pos.xz * 0.0046 + vec2(5.1, -3.2));
    float patch = noise2(world_pos.xz * 0.0018 + vec2(11.2, -7.4));

    vec3 grass = texture(grass_tex, uv_a).rgb;
    vec3 dirt = texture(dirt_tex, uv_a * 0.86 + vec2(3.1, 1.7)).rgb;
    vec3 rock = texture(rock_tex, uv_b).rgb;
    float r_grass = texture(grass_rough, uv_a).r;
    float r_dirt = texture(dirt_rough, uv_a * 0.86 + vec2(3.1, 1.7)).r;
    float r_rock = texture(rock_rough, uv_b).r;

    float slope = clamp(1.0 - abs(normalize(world_nrm).y), 0.0, 1.0);
    float altitude = max(world_pos.y, 0.0);
    float shoreline = 1.0 - smoothstep(2.5, 10.0, altitude);
    float lowland = smoothstep(3.0, 18.0, altitude) * (1.0 - smoothstep(70.0, 170.0, altitude));
    float midland = smoothstep(18.0, 42.0, altitude) * (1.0 - smoothstep(190.0, 295.0, altitude));
    float dry_zone = smoothstep(0.52, 0.84, macro + shoreline * 0.26);
    float rocky = clamp(smoothstep(0.32, 0.70, slope) + smoothstep(125.0, 245.0, altitude) * 0.34 + smoothstep(0.79, 0.95, detail) * 0.16, 0.0, 1.0);

    vec3 base = mix(grass, dirt, dry_zone * 0.48);
    base = mix(base, rock, rocky);

    // V21: the Gallipoli/Eceabat slopes must read as Mediterranean scrub and pine country rather
    // than one huge beige desert. Keep the immediate shore dry, then add olive/grass variation.
    float west_peninsula = 1.0 - smoothstep(-650.0, 550.0, world_pos.x);
    float west_green = west_peninsula * (lowland * 0.34 + midland * 0.58) * (0.55 + patch * 0.45);
    vec3 west_tint = vec3(base.r * 0.58, base.g * 0.88 + 0.055, base.b * 0.48);
    base = mix(base, west_tint, clamp(west_green, 0.0, 0.72));

    // Çanakkale is denser and more urban, but still has parks/trees and green peri-urban patches.
    float east_side = smoothstep(180.0, 950.0, world_pos.x);
    float east_green = east_side * (lowland * 0.20 + midland * 0.30) * smoothstep(0.48, 0.86, patch);
    vec3 east_tint = vec3(base.r * 0.70, base.g * 0.91 + 0.035, base.b * 0.61);
    base = mix(base, east_tint, clamp(east_green, 0.0, 0.44));

    // Narrow warm coastal band instead of kilometres of sand-coloured land.
    vec3 shore_tint = vec3(0.42, 0.38, 0.27);
    base = mix(base, shore_tint, shoreline * (0.20 + macro * 0.12));

    // Large scale albedo variation prevents the terrain from looking like a single flat texture.
    base *= mix(vec3(0.88, 0.92, 0.84), vec3(1.03, 1.01, 0.93), macro * 0.36);
    base *= 0.94 + detail * 0.10;

    ALBEDO = base;
    ROUGHNESS = clamp(mix(mix(r_grass, r_dirt, dry_zone), r_rock, rocky), 0.67, 0.98);
    METALLIC = 0.0;
    SPECULAR = 0.22;
}
