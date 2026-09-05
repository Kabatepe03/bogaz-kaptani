shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.015, 0.085, 0.12);
uniform vec3 shallow_color : source_color = vec3(0.04, 0.23, 0.29);
uniform float wave_height = 0.72;
uniform float wave_scale = 0.010;
uniform float speed = 0.45;

float wave(vec2 p, vec2 dir, float freq, float amp, float t) {
	return sin(dot(p, normalize(dir)) * freq + t * speed) * amp;
}

void vertex() {
	vec2 p = VERTEX.xz;
	float t = TIME;
	float h = wave(p, vec2(1.0,0.25), 0.050, 0.46, t)
		+ wave(p, vec2(-0.35,1.0), 0.080, 0.23, t * 1.21)
		+ wave(p, vec2(0.65,0.72), 0.145, 0.10, t * 1.65);
	VERTEX.y += h * wave_height;
}

void fragment() {
	vec3 n1 = normalize(vec3(sin((VERTEX.x + TIME*5.0)*0.10)*0.28, 1.0, cos((VERTEX.z - TIME*3.5)*0.12)*0.28));
	vec3 n2 = normalize(vec3(cos((VERTEX.z + TIME*4.0)*0.19)*0.16, 1.0, sin((VERTEX.x + TIME*2.0)*0.16)*0.16));
	NORMAL = normalize(mix(n1, n2, 0.45));
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
	ALBEDO = mix(shallow_color, deep_color, 0.58) + vec3(fresnel * 0.22);
	ROUGHNESS = mix(0.16, 0.34, fresnel);
	METALLIC = 0.05;
	SPECULAR = 0.86;
}
