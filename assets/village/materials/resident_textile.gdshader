shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// EVERBLOOM original resident textile material. Intended for authored UV-unwrapped
// clothing meshes; this does not generate clothing geometry or substitute for art.
// All textures must be original or independently license-verified.
uniform sampler2D cloth_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloth_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloth_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D weave_height : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 dye_tint : source_color = vec4(1.0);
uniform float normal_strength : hint_range(0.0, 2.0) = 0.75;
uniform float roughness_floor : hint_range(0.0, 1.0) = 0.55;
uniform float weave_roughness : hint_range(0.0, 0.3) = 0.08;
uniform float weave_repeat : hint_range(1.0, 24.0) = 6.0;
uniform float ambient_occlusion_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 base = texture(cloth_albedo, UV);
    float rough = texture(cloth_roughness, UV).r;
    float weave = texture(weave_height, UV * weave_repeat).r;
    ALBEDO = base.rgb * dye_tint.rgb;
    ALPHA = 1.0; // Opaque garment: avoid transparent sorting and mobile overdraw.
    NORMAL_MAP = texture(cloth_normal, UV).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp(max(rough, roughness_floor) + (weave - 0.5) * weave_roughness, 0.0, 1.0);
    METALLIC = 0.0;
    SPECULAR = 0.25;
    AO = 1.0;
    AO_LIGHT_AFFECT = ambient_occlusion_strength;
}
