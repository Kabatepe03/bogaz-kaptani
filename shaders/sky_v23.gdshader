shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.105, 0.285, 0.520);
uniform vec3 mid_sky_color : source_color = vec3(0.275, 0.505, 0.690);
uniform vec3 horizon_color : source_color = vec3(0.690, 0.755, 0.775);
uniform vec3 haze_color : source_color = vec3(0.720, 0.735, 0.715);
uniform vec3 cloud_light : source_color = vec3(0.940, 0.935, 0.900);
uniform vec3 cloud_mid : source_color = vec3(0.690, 0.715, 0.715);
uniform vec3 cloud_shadow : source_color = vec3(0.390, 0.445, 0.475);
uniform vec3 sun_color : source_color = vec3(1.0, 0.865, 0.630);
uniform float cloud_amount = 0.42;
uniform float haze_amount = 0.46;
uniform float cloud_speed = 0.009;
uniform float sun_elevation = 0.72;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.7);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amp = 0.53;
    mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
    for (int i = 0; i < 6; i++) {
        value += noise2(p) * amp;
        p = rot * p * 2.03 + vec2(6.8, 2.4);
        amp *= 0.47;
    }
    return value;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    float up = clamp(dir.y, 0.0, 1.0);
    float horizon = pow(1.0 - up, 4.2);

    // Approximate Rayleigh/Mie balance: saturated zenith, pale humid Dardanelles horizon.
    vec3 base = mix(horizon_color, mid_sky_color, smoothstep(0.02, 0.42, up));
    base = mix(base, zenith_color, smoothstep(0.30, 0.96, pow(up, 0.62)));
    float rayleigh = pow(max(up, 0.001), 0.35);
    base *= mix(vec3(1.04, 1.01, 0.96), vec3(0.92, 1.00, 1.08), rayleigh * 0.34);

    vec3 sun_dir = normalize(vec3(-0.36, sun_elevation, -0.48));
    float sun_dot = max(dot(dir, sun_dir), 0.0);
    float mie = pow(sun_dot, 7.0) * (0.11 + haze_amount * 0.13);
    float mie_wide = pow(sun_dot, 2.2) * haze_amount * 0.040;
    base += sun_color * (mie + mie_wide);

    // Low-altitude marine haze gives the opposite coast distance instead of a hard videogame cut.
    float horizon_haze = horizon * (0.24 + haze_amount * 0.52);
    base = mix(base, haze_color, clamp(horizon_haze, 0.0, 0.72));

    // Low cumulus deck: domain warped so cloud edges do not look like a scrolling 2D texture.
    vec2 low_uv = dir.xz / (0.15 + max(up, 0.055));
    low_uv += vec2(TIME * cloud_speed, -TIME * cloud_speed * 0.36);
    vec2 warp = vec2(
        fbm(low_uv * 0.31 + vec2(4.1, -7.3)),
        fbm(low_uv * 0.29 + vec2(-8.7, 3.9))
    ) - 0.5;
    low_uv += warp * 0.38;
    float broad = fbm(low_uv * 0.58);
    float detail = fbm(low_uv * 1.65 + vec2(12.7, -5.2));
    float erosion = fbm(low_uv * 4.1 + vec2(-3.4, 9.2));
    float density = broad * 0.70 + detail * 0.24 + erosion * 0.06;
    float threshold = 0.73 - cloud_amount * 0.25;
    float low_cloud = smoothstep(threshold, threshold + 0.14, density);
    low_cloud *= smoothstep(0.055, 0.20, up) * (1.0 - smoothstep(0.84, 0.99, up));
    float edge_light = smoothstep(0.50, 0.86, detail + sun_dot * 0.24);
    float underside = smoothstep(0.58, 0.82, broad - detail * 0.16);
    vec3 cloud = mix(cloud_mid, cloud_light, 0.28 + edge_light * 0.72);
    cloud = mix(cloud, cloud_shadow, underside * (0.34 + cloud_amount * 0.24));
    base = mix(base, cloud, low_cloud * 0.82);

    // High cirrus moves on another vector/scale and is intentionally faint.
    vec2 high_uv = dir.xz / (0.34 + max(up, 0.12));
    high_uv += vec2(-TIME * cloud_speed * 0.21, TIME * cloud_speed * 0.14);
    float cirrus_n = fbm(high_uv * 2.7 + vec2(19.0, -12.0));
    float cirrus = smoothstep(0.72, 0.91, cirrus_n) * smoothstep(0.34, 0.70, up) * (0.15 + cloud_amount * 0.20);
    base = mix(base, cloud_light, cirrus * 0.28);

    float sun_core = pow(sun_dot, 1100.0);
    float sun_disc = pow(sun_dot, 420.0);
    base += sun_color * (sun_core * 1.28 + sun_disc * 0.22);

    COLOR = max(base, vec3(0.0));
}
