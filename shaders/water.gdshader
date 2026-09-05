shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.008, 0.060, 0.115);
uniform vec3 mid_color : source_color = vec3(0.018, 0.145, 0.235);
uniform vec3 shallow_color : source_color = vec3(0.055, 0.285, 0.365);
uniform float wave_height = 0.82;
uniform float speed = 0.48;

float wave(vec2 p, vec2 dir, float freq, float amp, float t) {
	return sin(dot(p, normalize(dir)) * freq + t * speed) * amp;
}

float wave_field(vec2 p, float t) {
	return wave(p, vec2(1.0,0.22), 0.046, 0.55, t)
		+ wave(p, vec2(-0.34,1.0), 0.077, 0.30, t * 1.18)
		+ wave(p, vec2(0.72,0.63), 0.142, 0.14, t * 1.56)
		+ wave(p, vec2(-0.88,0.41), 0.205, 0.07, t * 1.82);
}

void vertex() {
	vec2 p = VERTEX.xz;
	VERTEX.y += wave_field(p, TIME) * wave_height;
}

void fragment() {
	vec2 p = VERTEX.xz;
	float t = TIME;
	vec3 n1 = normalize(vec3(
		sin((p.x + t * 5.4) * 0.095) * 0.30,
		1.0,
		cos((p.y - t * 3.8) * 0.118) * 0.30));
	vec3 n2 = normalize(vec3(
		cos((p.y + t * 4.2) * 0.185) * 0.17,
		1.0,
		sin((p.x + t * 2.6) * 0.158) * 0.17));
	NORMAL = normalize(mix(n1, n2, 0.46));

	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.4);
	float broad = sin(p.x * 0.007 + p.y * 0.005 + t * 0.32) * 0.5 + 0.5;
	vec3 base = mix(deep_color, mid_color, 0.52 + broad * 0.18);
	base = mix(base, shallow_color, fresnel * 0.34);

	float crest = wave_field(p, t);
	float foam = smoothstep(0.77, 1.02, crest) * 0.23;
	ALBEDO = base + vec3(fresnel * 0.20) + vec3(foam);
	ROUGHNESS = mix(0.11, 0.30, fresnel) + foam * 0.22;
	METALLIC = 0.04;
	SPECULAR = 0.92;
}
