shader_type spatial;
// EVERBLOOM E19: original leaf PBR maps; candidate material, NOT production-approved.
// UV.y=0 anchors the stem; maps authored by make_leaf_maps.py.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_roughness : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 leaf_tint : source_color = vec4(0.84, 0.96, 0.82, 1.0);
uniform vec3 underside_tint : source_color = vec3(0.78, 0.88, 0.69);
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.48;
uniform float wind_strength : hint_range(0.0, 0.35) = 0.06;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.1;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.55;
uniform float roughness_scale : hint_range(0.0, 1.0) = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.18;
uniform bool reduced_motion = false;

void vertex() {
    vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float seed = dot(origin.xz, vec2(0.127, 0.319));
    float phase = TIME * wind_speed + seed;
    float gust = sin(phase + 0.8 * sin(TIME * 0.37 + seed));
    float flutter = sin(phase * 1.71 + origin.x * 0.022);
    float anchor = smoothstep(0.05, 0.95, UV.y);
    float bend = reduced_motion ? 0.0 : (gust * 0.72 + flutter * 0.28) * wind_strength * anchor;
    VERTEX.x += bend;
    VERTEX.z += bend * 0.42;
}

void fragment() {
    vec4 texel = texture(leaf_albedo, UV);
    ALPHA = texel.a * leaf_tint.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
    vec3 color = texel.rgb * leaf_tint.rgb;
    ALBEDO = FRONT_FACING ? color : color * underside_tint;
    NORMAL_MAP = texture(leaf_normal, UV).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = clamp(texture(leaf_roughness, UV).r * roughness_scale, 0.2, 1.0);
    SPECULAR = 0.18;
    BACKLIGHT = ALBEDO * translucency;
}
