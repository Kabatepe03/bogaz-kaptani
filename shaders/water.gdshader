shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.006, 0.050, 0.095);
uniform vec3 body_color : source_color = vec3(0.014, 0.130, 0.220);
uniform vec3 surface_color : source_color = vec3(0.070, 0.300, 0.365);
uniform vec3 foam_color : source_color = vec3(0.78, 0.86, 0.87);
uniform float wave_height = 0.90;
uniform float speed = 0.52;

float wave(vec2 p, vec2 dir, float freq, float amp, float phase) {
	return sin(dot(p, normalize(dir)) * freq + phase) * amp;
}

float field(vec2 p, float t) {
	return wave(p, vec2(1.0, 0.18), 0.040, 0.55, t * speed)
		+ wave(p, vec2(-0.28, 1.0), 0.073, 0.31, t * speed * 1.23)
		+ wave(p, vec2(0.72, 0.60), 0.125, 0.16, t * speed * 1.58)
		+ wave(p, vec2(-0.83, 0.44), 0.205, 0.08, t * speed * 1.92)
		+ wave(p, vec2(0.31, -0.95), 0.330, 0.035, t * speed * 2.25);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float broad = field(p, TIME);
	float chop = sin((p.x * 0.17) + (p.y * 0.12) + TIME * 1.8) * 0.08;
	VERTEX.y += (broad + chop) * wave_height;
}

void fragment() {
	vec2 p = VERTEX.xz;
	float t = TIME;
	float sx = sin((p.x + t * 7.0) * 0.095) * 0.27 + sin((p.y - t * 4.0) * 0.185) * 0.10;
	float sz = cos((p.y - t * 5.2) * 0.118) * 0.28 + cos((p.x + t * 3.1) * 0.215) * 0.10;
	NORMAL = normalize(vec3(sx, 1.0, sz));

	float ndv = max(dot(NORMAL, VIEW), 0.0);
	float fresnel = pow(1.0 - ndv, 4.7);
	float broad = field(p, t);
	float long_band = sin(p.x * 0.0048 + p.y * 0.0062 + t * 0.23) * 0.5 + 0.5;
	float micro = sin((p.x + p.y) * 0.11 + t * 1.6) * 0.5 + 0.5;

	vec3 base = mix(deep_color, body_color, 0.44 + long_band * 0.28);
	base = mix(base, surface_color, fresnel * 0.42 + micro * 0.035);

	vec3 sun_dir = normalize(vec3(-0.42, 0.84, -0.34));
	vec3 reflected = reflect(-sun_dir, NORMAL);
	float glint = pow(max(dot(reflected, VIEW), 0.0), 72.0);
	float soft_glint = pow(max(dot(reflected, VIEW), 0.0), 18.0) * 0.22;

	float crest = smoothstep(0.72, 1.08, broad);
	float broken = smoothstep(0.66, 0.96, broad + sin(p.x * 0.52 + p.y * 0.41 + t * 2.6) * 0.11);
	float foam = crest * 0.42 + broken * crest * 0.28;

	ALBEDO = mix(base, foam_color, clamp(foam, 0.0, 0.58));
	ALBEDO += vec3(glint * 0.54 + soft_glint);
	ROUGHNESS = clamp(0.14 + fresnel * 0.11 + foam * 0.36, 0.12, 0.62);
	METALLIC = 0.035;
	SPECULAR = 0.94;
}
