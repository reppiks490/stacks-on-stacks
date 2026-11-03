shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Original material for the existing UV-mapped 13-voussoir arch.
// Bind original or independently rights-verified maps. Not finished stone art.
uniform sampler2D stone_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 mortar_tint : source_color = vec4(0.69, 0.64, 0.57, 1.0);
uniform float texture_scale : hint_range(0.1, 12.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.75;
uniform float roughness_floor : hint_range(0.0, 1.0) = 0.62;
uniform float surface_variation : hint_range(0.0, 0.2) = 0.035;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV * texture_scale;
    vec3 base = texture(stone_albedo, uv).rgb;
    float grain = hash21(floor(uv * 48.0)) - 0.5;
    ALBEDO = clamp(base * mortar_tint.rgb * (1.0 + grain * surface_variation), vec3(0.0), vec3(1.0));
    NORMAL_MAP = texture(stone_normal, uv).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp(max(roughness_floor, texture(stone_roughness, uv).r), 0.0, 1.0);
    METALLIC = 0.0;
}
