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
    vec2 uv_near = world_pos.xz * 0.026;
    vec2 uv_mid = (world_pos.xz + vec2(world_pos.z, -world_pos.x) * 0.21) * 0.0075;
    vec2 uv_far = world_pos.xz * 0.0011;
    float macro = noise2(uv_far + vec2(7.3, -4.1));
    float macro2 = noise2(world_pos.xz * 0.00039 + vec2(-9.0, 12.0));
    float detail = noise2(world_pos.xz * 0.0053 + vec2(5.1, -3.2));
    float patch = noise2(world_pos.xz * 0.0020 + vec2(11.2, -7.4));

    vec3 grass = texture(grass_tex, uv_near).rgb;
    vec3 dirt = texture(dirt_tex, uv_near * 0.86 + vec2(3.1, 1.7)).rgb;
    vec3 rock = texture(rock_tex, uv_mid).rgb;
    float r_grass = texture(grass_rough, uv_near).r;
    float r_dirt = texture(dirt_rough, uv_near * 0.86 + vec2(3.1, 1.7)).r;
    float r_rock = texture(rock_rough, uv_mid).r;

    float slope = clamp(1.0 - abs(normalize(world_nrm).y), 0.0, 1.0);
    float altitude = max(world_pos.y, 0.0);
    float shore = 1.0 - smoothstep(1.6, 8.0, altitude);
    float lowland = smoothstep(2.0, 13.0, altitude) * (1.0 - smoothstep(82.0, 150.0, altitude));
    float midland = smoothstep(18.0, 48.0, altitude) * (1.0 - smoothstep(185.0, 300.0, altitude));
    float rocky = clamp(smoothstep(0.28, 0.66, slope) + smoothstep(138.0, 255.0, altitude) * 0.38 + smoothstep(0.82, 0.97, detail) * 0.15, 0.0, 1.0);
    float dry_patch = smoothstep(0.60, 0.92, macro * 0.72 + macro2 * 0.28 + shore * 0.18);

    vec3 grass_tinted = grass * vec3(0.78, 0.96, 0.66);
    vec3 dirt_tinted = dirt * vec3(0.82, 0.78, 0.66);
    vec3 base = mix(grass_tinted, dirt_tinted, dry_patch * 0.43);
    base = mix(base, rock * vec3(0.88, 0.90, 0.84), rocky);

    // Gallipoli/Eceabat: Mediterranean maquis, pine and olive country. Stronger green identity
    // than the v20 beige prototype, while still leaving dry summer clearings visible.
    float west = 1.0 - smoothstep(-500.0, 600.0, world_pos.x);
    float west_cover = west * clamp(lowland * 0.58 + midland * 0.76 + patch * 0.26, 0.0, 1.0);
    vec3 pine_ground = vec3(0.19, 0.285, 0.125);
    vec3 olive_ground = vec3(0.255, 0.335, 0.145);
    vec3 west_ground = mix(pine_ground, olive_ground, macro2);
    base = mix(base, west_ground, clamp(west_cover * (0.52 + macro * 0.22), 0.0, 0.78));

    // Çanakkale side: more urban/dry but with park and garden patches around the waterfront.
    float east = smoothstep(120.0, 760.0, world_pos.x);
    float urban_green = east * lowland * smoothstep(0.44, 0.88, patch) * 0.42;
    base = mix(base, vec3(0.29, 0.36, 0.17), urban_green);

    // Narrow rocky/warm shore instead of kilometres of bright sand.
    vec3 shore_rock = mix(vec3(0.34, 0.32, 0.25), vec3(0.40, 0.36, 0.27), macro);
    base = mix(base, shore_rock, shore * 0.34);

    // Macro colour breakup and slight atmospheric desaturation at high ground.
    base *= mix(vec3(0.90, 0.94, 0.88), vec3(1.04, 1.02, 0.94), macro * 0.42);
    base *= 0.93 + detail * 0.11;
    base = mix(base, base * vec3(0.91, 0.93, 0.95), smoothstep(180.0, 310.0, altitude) * 0.18);

    ALBEDO = base;
    ROUGHNESS = clamp(mix(mix(r_grass, r_dirt, dry_patch), r_rock, rocky), 0.68, 0.98);
    METALLIC = 0.0;
    SPECULAR = 0.20;
}
