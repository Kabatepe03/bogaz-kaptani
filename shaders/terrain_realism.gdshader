shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform vec3 beach_color : source_color = vec3(0.39, 0.34, 0.24);
uniform vec3 dry_grass : source_color = vec3(0.22, 0.29, 0.11);
uniform vec3 green_grass : source_color = vec3(0.12, 0.25, 0.075);
uniform vec3 forest_color : source_color = vec3(0.065, 0.16, 0.045);
uniform vec3 rock_color : source_color = vec3(0.28, 0.27, 0.23);
uniform vec3 high_rock : source_color = vec3(0.39, 0.37, 0.32);

varying vec3 world_pos;
varying float slope_amount;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slope_amount = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
}

void fragment() {
	float h = world_pos.y;
	float large_noise = fbm(world_pos.xz * 0.0031);
	float detail_noise = fbm(world_pos.xz * 0.018 + vec2(31.0, 8.0));
	float slope = smoothstep(0.16, 0.62, slope_amount);

	vec3 low = mix(beach_color, dry_grass, smoothstep(1.2, 9.0, h));
	vec3 grass = mix(dry_grass, green_grass, smoothstep(10.0, 58.0, h));
	grass = mix(grass, forest_color, smoothstep(0.48, 0.78, large_noise) * smoothstep(18.0, 75.0, h));
	vec3 base = mix(low, grass, smoothstep(7.0, 25.0, h));

	vec3 rocky = mix(rock_color, high_rock, smoothstep(95.0, 180.0, h));
	float rock_mix = max(slope, smoothstep(135.0, 220.0, h) * 0.68);
	base = mix(base, rocky, rock_mix);

	float tint = (detail_noise - 0.5) * 0.12;
	ALBEDO = clamp(base + vec3(tint, tint * 0.82, tint * 0.56), vec3(0.02), vec3(0.86));
	ROUGHNESS = mix(0.93, 0.78, rock_mix);
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
