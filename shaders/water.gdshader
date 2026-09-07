shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.010, 0.055, 0.090);
uniform vec3 body_color : source_color = vec3(0.018, 0.115, 0.165);
uniform vec3 surface_color : source_color = vec3(0.055, 0.205, 0.245);
uniform vec3 foam_color : source_color = vec3(0.80, 0.86, 0.86);
uniform float wave_height = 0.38;
uniform float speed = 0.34;

float wave(vec2 p, vec2 dir, float freq, float amp, float phase) {
	return sin(dot(p, normalize(dir)) * freq + phase) * amp;
}

float field(vec2 p, float t) {
	return wave(p, vec2(1.0, 0.14), 0.022, 0.50, t * speed)
		+ wave(p, vec2(-0.31, 1.0), 0.041, 0.25, t * speed * 1.18)
		+ wave(p, vec2(0.70, 0.64), 0.074, 0.12, t * speed * 1.42)
		+ wave(p, vec2(-0.82, 0.42), 0.128, 0.055, t * speed * 1.75);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float broad = field(p, TIME);
	float ripple = sin((p.x * 0.095) + (p.y * 0.072) + TIME * 1.05) * 0.035;
	VERTEX.y += (broad + ripple) * wave_height;
}

void fragment() {
	vec2 p = VERTEX.xz;
	float t = TIME;
	float sx = sin((p.x + t * 3.8) * 0.055) * 0.105 + sin((p.y - t * 2.2) * 0.105) * 0.040;
	float sz = cos((p.y - t * 3.0) * 0.061) * 0.110 + cos((p.x + t * 2.0) * 0.118) * 0.040;
	NORMAL = normalize(vec3(sx, 1.0, sz));

	float ndv = max(dot(NORMAL, VIEW), 0.0);
	float fresnel = pow(1.0 - ndv, 5.2);
	float broad = field(p, t);
	float long_band = sin(p.x * 0.0028 + p.y * 0.0039 + t * 0.13) * 0.5 + 0.5;

	vec3 base = mix(deep_color, body_color, 0.48 + long_band * 0.20);
	base = mix(base, surface_color, fresnel * 0.30);

	vec3 sun_dir = normalize(vec3(-0.42, 0.84, -0.34));
	vec3 reflected = reflect(-sun_dir, NORMAL);
	float glint = pow(max(dot(reflected, VIEW), 0.0), 96.0) * 0.38;
	float soft_glint = pow(max(dot(reflected, VIEW), 0.0), 28.0) * 0.08;

	float crest = smoothstep(0.88, 1.18, broad);
	float breakup = sin(p.x * 0.27 + p.y * 0.31 + t * 1.5) * 0.5 + 0.5;
	float foam = crest * breakup * 0.16;

	ALBEDO = mix(base, foam_color, clamp(foam, 0.0, 0.18));
	ALBEDO += vec3(glint + soft_glint);
	ROUGHNESS = clamp(0.24 + fresnel * 0.10 + foam * 0.26, 0.22, 0.48);
	METALLIC = 0.015;
	SPECULAR = 0.72;
}
