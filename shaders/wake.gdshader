shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_alpha_prepass, blend_mix;

uniform vec3 foam_color : source_color = vec3(0.82, 0.91, 0.94);
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
	VERTEX.y += sin(VERTEX.z * 0.10 + TIME * 1.8) * 0.022;
}

void fragment() {
	vec2 uv = UV;
	float x = uv.x - 0.5;
	float tail = smoothstep(0.01, 0.12, uv.y) * (1.0 - smoothstep(0.76, 1.0, uv.y));

	// Two diverging shoulders plus a weaker centre propeller wash.
	float spread = mix(0.06, 0.44, uv.y);
	float shoulder = exp(-pow((abs(x) - spread * 0.55) / 0.075, 2.0));
	float centre = exp(-pow(x / mix(0.13, 0.05, uv.y), 2.0)) * (1.0 - uv.y) * 0.72;
	float breakup = noise2(vec2(uv.x * 24.0 + TIME * 0.35, uv.y * 42.0 - TIME * 2.1));
	float streak = noise2(vec2(uv.x * 57.0 - TIME * 0.55, uv.y * 13.0 + TIME * 0.8));
	float mask = max(shoulder, centre) * tail;
	float foam = mask * smoothstep(0.28, 0.72, breakup * 0.72 + streak * 0.28);

	ALBEDO = foam_color;
	ALPHA = foam * strength * 0.62;
}
