shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.20, 0.43, 0.68);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.79, 0.84);
uniform vec3 low_haze_color : source_color = vec3(0.78, 0.80, 0.78);
uniform vec3 cloud_light : source_color = vec3(0.92, 0.93, 0.91);
uniform vec3 cloud_shadow : source_color = vec3(0.48, 0.55, 0.59);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.62);
uniform float cloud_amount = 0.52;
uniform float cloud_speed = 0.018;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
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
    float value = 0.0;
    float amp = 0.52;
    mat2 rot = mat2(vec2(0.82, -0.57), vec2(0.57, 0.82));
    for (int i = 0; i < 4; i++) {
        value += noise2(p) * amp;
        p = rot * p * 2.03 + vec2(7.7, 3.2);
        amp *= 0.48;
    }
    return value;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    float up = clamp(dir.y, 0.0, 1.0);
    float horizon = pow(1.0 - up, 3.5);
    vec3 sky_col = mix(horizon_color, zenith_color, pow(up, 0.46));
    sky_col = mix(sky_col, low_haze_color, horizon * 0.28);

    // Project cloud noise onto a high atmospheric layer. The extra denominator prevents giant
    // stretched blobs directly at the horizon and keeps the Dardanelles skyline readable.
    float cloud_visibility = smoothstep(0.025, 0.16, up) * (1.0 - smoothstep(0.86, 1.0, up) * 0.20);
    vec2 cloud_uv = dir.xz / (0.18 + up) * 1.18;
    cloud_uv += vec2(TIME * cloud_speed, -TIME * cloud_speed * 0.43);
    float broad = fbm(cloud_uv * 0.72);
    float detail = fbm(cloud_uv * 2.25 + vec2(12.3, -5.4));
    float density = broad * 0.74 + detail * 0.26;
    float cloud_mask = smoothstep(0.57 - cloud_amount * 0.18, 0.76 - cloud_amount * 0.12, density);
    cloud_mask *= cloud_visibility;
    float silver = smoothstep(0.62, 0.90, detail);
    vec3 clouds = mix(cloud_shadow, cloud_light, 0.58 + silver * 0.32);
    sky_col = mix(sky_col, clouds, cloud_mask * 0.72);

    // Broad hazy sun rather than a videogame-white dot.
    vec3 sun_dir = normalize(vec3(-0.38, 0.78, -0.49));
    float sun_dot = max(dot(dir, sun_dir), 0.0);
    float sun_core = pow(sun_dot, 920.0);
    float sun_glow = pow(sun_dot, 28.0) * 0.18;
    sky_col += sun_color * (sun_core * 1.35 + sun_glow);

    COLOR = sky_col;
}
