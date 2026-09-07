shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_rough : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = world_pos.xz * 0.055;
    vec3 asphalt = texture(asphalt_tex, uv).rgb;
    float rough = texture(asphalt_rough, uv).r;
    float large = sin(world_pos.x * 0.007 + world_pos.z * 0.004) * 0.5 + 0.5;
    asphalt *= 0.80 + large * 0.12;
    ALBEDO = asphalt;
    ROUGHNESS = clamp(rough * 0.92 + 0.07, 0.70, 0.98);
    METALLIC = 0.0;
    SPECULAR = 0.26;
}
