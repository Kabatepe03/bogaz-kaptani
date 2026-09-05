shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_alpha_prepass, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.88, 0.96, 1.0);
uniform float strength = 0.88;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
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

void vertex() {
	VERTEX.y += sin(VERTEX.z * 0.15 + TIME * 2.2) * 0.035;
}

void fragment() {
	vec2 uv = UV;
	float center = 1.0 - smoothstep(0.0, 0.48, abs(uv.x - 0.5));
	float tail = smoothstep(0.02, 0.25, uv.y) * (1.0 - smoothstep(0.68, 1.0, uv.y));
	float breakup = noise2(vec2(uv.x * 17.0, uv.y * 28.0 - TIME * 2.6));
	float streak = sin((uv.x - 0.5) * 38.0 + uv.y * 19.0 - TIME * 3.0) * 0.5 + 0.5;
	float alpha = center * tail * smoothstep(0.30, 0.76, breakup * 0.72 + streak * 0.38) * strength;
	ALBEDO = foam_color;
	ALPHA = alpha * 0.72;
}
