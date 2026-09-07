shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.006, 0.040, 0.072);
uniform vec3 body_color : source_color = vec3(0.012, 0.105, 0.155);
uniform vec3 sky_reflect : source_color = vec3(0.19, 0.39, 0.50);
uniform vec3 crest_color : source_color = vec3(0.50, 0.67, 0.70);
uniform float wave_height = 0.52;
uniform float speed = 0.42;

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

float wave(vec2 p, vec2 dir, float freq, float amp, float phase) {
	return sin(dot(p, normalize(dir)) * freq + phase) * amp;
}

float sea_field(vec2 p, float t) {
	float large = wave(p, vec2(1.0, 0.17), 0.0185, 0.52, t * speed)
		+ wave(p, vec2(-0.37, 1.0), 0.031, 0.31, t * speed * 1.16)
		+ wave(p, vec2(0.73, 0.62), 0.057, 0.17, t * speed * 1.47)
		+ wave(p, vec2(-0.88, 0.39), 0.101, 0.075, t * speed * 1.79);
	float warped = noise2(p * 0.013 + vec2(t * 0.022, -t * 0.015)) - 0.5;
	float detail = noise2(p * 0.046 + vec2(-t * 0.075, t * 0.053)) - 0.5;
	return large + warped * 0.22 + detail * 0.075;
}

void vertex() {
	vec2 p = VERTEX.xz;
	VERTEX.y += sea_field(p, TIME) * wave_height;
}

void fragment() {
	vec2 p = VERTEX.xz;
	float t = TIME;

	float n0 = noise2(p * 0.020 + vec2(t * 0.032, -t * 0.020));
	float n1 = noise2(p * 0.072 + vec2(-t * 0.090, t * 0.061));
	float n2 = noise2(p * 0.155 + vec2(t * 0.135, t * 0.087));

	float slope_x = sin(p.x * 0.030 + p.y * 0.011 + t * 0.62) * 0.105
		+ sin(p.x * 0.084 - p.y * 0.031 + t * 1.05) * 0.038
		+ (n1 - 0.5) * 0.075;
	float slope_z = cos(p.y * 0.034 - p.x * 0.013 + t * 0.55) * 0.110
		+ cos(p.y * 0.091 + p.x * 0.026 + t * 0.94) * 0.040
		+ (n2 - 0.5) * 0.070;
	NORMAL = normalize(vec3(slope_x, 1.0, slope_z));

	float ndv = max(dot(NORMAL, VIEW), 0.0);
	float fresnel = pow(1.0 - ndv, 4.6);
	float depth_variation = clamp(0.28 + n0 * 0.44 + n1 * 0.12, 0.0, 1.0);
	vec3 base = mix(deep_color, body_color, depth_variation);
	base = mix(base, sky_reflect, fresnel * 0.47);

	vec3 sun_dir = normalize(vec3(-0.44, 0.82, -0.35));
	vec3 reflected = reflect(-sun_dir, NORMAL);
	float pin_glint = pow(max(dot(reflected, VIEW), 0.0), 118.0) * 0.64;
	float broad_glint = pow(max(dot(reflected, VIEW), 0.0), 24.0) * 0.095;

	float sea_h = sea_field(p, t);
	float broken = noise2(p * 0.11 + vec2(t * 0.11, -t * 0.08));
	float crest = smoothstep(0.82, 1.08, sea_h) * smoothstep(0.57, 0.82, broken);
	base = mix(base, crest_color, crest * 0.075);

	ALBEDO = base + vec3(pin_glint + broad_glint);
	ROUGHNESS = clamp(0.20 + (1.0 - fresnel) * 0.10 + n2 * 0.055, 0.18, 0.38);
	METALLIC = 0.018;
	SPECULAR = 0.86;
}
