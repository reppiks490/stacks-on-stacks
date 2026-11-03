shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Original EVERBLOOM resident skin material. Requires authored UVs and
// independently owned/licensed textures; not a substitute for character art.
// Linearized color/normal sampling is handled by Godot's source hints.
uniform sampler2D skin_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D skin_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D skin_microdetail : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 skin_tint : source_color = vec4(1.0, 0.96, 0.93, 1.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.65;
uniform float roughness_bias : hint_range(-0.3, 0.3) = 0.0;
uniform float micro_roughness : hint_range(0.0, 0.25) = 0.055;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.18;
uniform float micro_tiling : hint_range(1.0, 32.0) = 8.0;

void fragment() {
    vec3 color_sample = texture(skin_albedo, UV).rgb;
    vec3 normal_sample = texture(skin_normal, UV).rgb;
    float authored_roughness = texture(skin_roughness, UV).r;
    float micro = texture(skin_microdetail, UV * micro_tiling).r - 0.5;

    ALBEDO = color_sample * skin_tint.rgb;
    NORMAL_MAP = normal_sample;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp(authored_roughness + roughness_bias + micro * micro_roughness, 0.12, 0.95);
    METALLIC = 0.0;
    SPECULAR = 0.45;
    SSS_STRENGTH = subsurface_strength;
}
