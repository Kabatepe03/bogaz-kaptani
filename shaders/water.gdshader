shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.004, 0.042, 0.086);
uniform vec3 mid_color : source_color = vec3(0.012, 0.105, 0.185);
uniform vec3 shallow_color : source_color = vec3(0.035, 0.235, 0.310);
uniform vec3 foam_color : source_color = vec3(0.83, 0.93, 0.96);
uniform float wave_height = 0.92;
uniform float speed = 0.54;

varying float crest_value;
varying vec3 world_pos;

float wave(vec2 p, vec2 dir, float freq, float amp, float t) {
	return sin(dot(p, normalize(dir)) * freq + t * speed) * amp;
}

float wave_field(vec2 p, float t) {
	return wave(p, vec2(1.0,0.18), 0.041, 0.58, t)
		+ wave(p, vec2(-0.30,1.0), 0.071, 0.32, t * 1.17)
		+ wave(p, vec2(0.76,0.56), 0.137, 0.16, t * 1.54)
		+ wave(p, vec2(-0.90,0.38), 0.212, 0.075, t * 1.91)
		+ wave(p, vec2(0.26,-1.0), 0.315, 0.035, t * 2.28);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float h = wave_field(p, TIME);
	VERTEX.y += h * wave_height;
	crest_value = h;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME;
	float sx = sin((p.x + t * 6.0) * 0.083) * 0.25 + sin((p.x - t * 2.8) * 0.21) * 0.10;
	float sz = cos((p.y - t * 4.1) * 0.106) * 0.25 + cos((p.y + t * 3.6) * 0.19) * 0.10;
	vec3 n1 = normalize(vec3(sx, 1.0, sz));
	vec3 n2 = normalize(vec3(
		cos((p.y + t * 5.0) * 0.23) * 0.16,
		1.0,
		sin((p.x + t * 3.2) * 0.205) * 0.16));
	NORMAL = normalize(mix(n1, n2, 0.44));

	float ndv = max(dot(NORMAL, VIEW), 0.0);
	float fresnel = pow(1.0 - ndv, 4.8);
	float broad = sin(p.x * 0.0055 + p.y * 0.0037 + t * 0.28) * 0.5 + 0.5;
	float current_band = sin(p.x * 0.0017 - p.y * 0.0024 + t * 0.16) * 0.5 + 0.5;
	vec3 base = mix(deep_color, mid_color, 0.46 + broad * 0.24);
	base = mix(base, shallow_color, current_band * 0.12 + fresnel * 0.26);

	float crest = smoothstep(0.72, 1.06, crest_value);
	float broken = hash21(floor(p * 0.38 + vec2(t * 0.8, -t * 0.35)));
	float foam = crest * smoothstep(0.30, 0.82, broken) * 0.42;
	float sparkle_seed = hash21(floor(p * 1.65 + vec2(t * 2.0, -t * 1.4)));
	float sparkle = smoothstep(0.965, 1.0, sparkle_seed) * pow(1.0 - abs(ndv - 0.42), 7.0) * 0.52;

	ALBEDO = base + vec3(fresnel * 0.16) + foam_color * foam + vec3(sparkle);
	ROUGHNESS = clamp(0.10 + fresnel * 0.20 + foam * 0.30, 0.08, 0.48);
	METALLIC = 0.025;
	SPECULAR = 0.96;
}
