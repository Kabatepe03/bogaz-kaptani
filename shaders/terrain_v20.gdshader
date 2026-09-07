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
    float macro = noise2(world_pos.xz * 0.00062);
    float detail = noise2(world_pos.xz * 0.0048);
    float patch = noise2(world_pos.xz * 0.00155 + vec2(11.2, -7.4));

    vec3 grass = texture(grass_tex, uv_a).rgb;
    vec3 dirt = texture(dirt_tex, uv_a * 0.86 + vec2(3.1, 1.7)).rgb;
    vec3 rock = texture(rock_tex, uv_b).rgb;
    float r_grass = texture(grass_rough, uv_a).r;
    float r_dirt = texture(dirt_rough, uv_a * 0.86 + vec2(3.1, 1.7)).r;
    float r_rock = texture(rock_rough, uv_b).r;

    float slope = clamp(1.0 - abs(normalize(world_nrm).y), 0.0, 1.0);
    float altitude = max(world_pos.y, 0.0);
    float shore = 1.0 - smoothstep(5.0, 24.0, altitude);
    float dry_zone = smoothstep(0.42, 0.78, macro + shore * 0.20);
    float rocky = clamp(smoothstep(0.30, 0.72, slope) + smoothstep(105.0, 240.0, altitude) * 0.38 + smoothstep(0.76, 0.94, detail) * 0.18, 0.0, 1.0);

    vec3 base = mix(grass, dirt, dry_zone * 0.62);
    base = mix(base, rock, rocky);

    // Gallipoli/Eceabat should read as Mediterranean scrub/olive landscape, not a sand desert.
    float west_peninsula = 1.0 - smoothstep(-900.0, 350.0, world_pos.x);
    float mid_slope_green = smoothstep(8.0, 30.0, altitude) * (1.0 - smoothstep(180.0, 285.0, altitude));
    float vegetation_tint = clamp(west_peninsula * mid_slope_green * (0.26 + patch * 0.42), 0.0, 0.62);
    vec3 olive_tint = vec3(base.r * 0.72, base.g * 0.90, base.b * 0.60);
    base = mix(base, olive_tint, vegetation_tint);

    // Çanakkale side still has dry summer ground but gets patchy urban/peri-urban greens.
    float east_green = smoothstep(250.0, 950.0, world_pos.x) * mid_slope_green * smoothstep(0.58, 0.86, patch) * 0.20;
    base = mix(base, vec3(base.r * 0.78, base.g * 0.92, base.b * 0.68), east_green);

    base *= mix(vec3(0.90, 0.93, 0.86), vec3(1.04, 1.00, 0.91), macro * 0.30);
    base = mix(base, vec3(0.34, 0.33, 0.25), shore * 0.13);

    ALBEDO = base;
    ROUGHNESS = clamp(mix(mix(r_grass, r_dirt, dry_zone), r_rock, rocky), 0.62, 0.98);
    METALLIC = 0.0;
    SPECULAR = 0.24;
}
