shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.18, 0.39, 0.63);
uniform vec3 high_haze : source_color = vec3(0.48, 0.63, 0.74);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.78, 0.79);
uniform vec3 cloud_light : source_color = vec3(0.91, 0.92, 0.89);
uniform vec3 cloud_mid : source_color = vec3(0.69, 0.72, 0.71);
uniform vec3 cloud_shadow : source_color = vec3(0.45, 0.51, 0.54);
uniform vec3 sun_color : source_color = vec3(1.0, 0.87, 0.66);
uniform float cloud_amount = 0.56;
uniform float cloud_speed = 0.012;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.7);
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
    for (int i = 0; i < 5; i++) {
        value += noise2(p) * amp;
        p = rot * p * 2.02 + vec2(6.4, 2.7);
        amp *= 0.48;
    }
    return value;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    float up = clamp(dir.y, 0.0, 1.0);
    float horizon = pow(1.0 - up, 3.2);
    vec3 base = mix(horizon_color, zenith_color, pow(up, 0.53));
    base = mix(base, high_haze, smoothstep(0.02, 0.35, up) * horizon * 0.22);

    vec2 cloud_uv = dir.xz / (0.20 + up) * 0.92;
    cloud_uv += vec2(TIME * cloud_speed, -TIME * cloud_speed * 0.38);
    float broad = fbm(cloud_uv * 0.73);
    float detail = fbm(cloud_uv * 2.10 + vec2(13.7, -4.1));
    float wisps = fbm(cloud_uv * 4.25 + vec2(-7.2, 11.6));
    float density = broad * 0.66 + detail * 0.25 + wisps * 0.09;
    float cloud_mask = smoothstep(0.58 - cloud_amount * 0.18, 0.76 - cloud_amount * 0.12, density);
    cloud_mask *= smoothstep(0.045, 0.19, up) * (1.0 - smoothstep(0.89, 1.0, up) * 0.24);
    float lit = smoothstep(0.52, 0.88, detail);
    float dark = smoothstep(0.61, 0.82, broad - detail * 0.18);
    vec3 cloud = mix(cloud_mid, cloud_light, lit * 0.70 + 0.24);
    cloud = mix(cloud, cloud_shadow, dark * 0.43);
    base = mix(base, cloud, cloud_mask * 0.70);

    vec3 sun_dir = normalize(vec3(-0.34, 0.78, -0.53));
    float sun_dot = max(dot(dir, sun_dir), 0.0);
    float sun_core = pow(sun_dot, 760.0);
    float sun_halo = pow(sun_dot, 24.0) * 0.14;
    base += sun_color * (sun_core * 1.20 + sun_halo);

    float horizon_glow = pow(1.0 - up, 7.5) * 0.065;
    base += vec3(0.76, 0.72, 0.63) * horizon_glow;
    COLOR = base;
}
