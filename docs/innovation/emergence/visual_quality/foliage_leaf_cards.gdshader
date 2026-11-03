shader_type spatial;
// EVERBLOOM original foliage shading experiment. No third-party textures.
// For authored leaf-card meshes with UVs; NOT a replacement for detailed tree models.
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;
uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec4 leaf_tint : source_color = vec4(0.39, 0.61, 0.34, 1.0);
uniform vec4 underside_tint : source_color = vec4(0.57, 0.68, 0.38, 1.0);
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.48;
uniform float wind_strength : hint_range(0.0, 0.35) = 0.08;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.1;
uniform float gust_scale : hint_range(0.001, 0.2) = 0.022;
uniform float roughness_value : hint_range(0.2, 1.0) = 0.84;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.55;
uniform float translucency : hint_range(0.0, 1.0) = 0.22;
uniform bool reduced_motion = false;
varying float wind_phase;

void vertex() {
    vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float seed = dot(world_origin.xz, vec2(0.127, 0.319));
    float phase = TIME * wind_speed + seed;
    float gust = sin(phase + sin(TIME * 0.37 + seed) * 0.8);
    float secondary = sin(phase * 1.71 + world_origin.x * gust_scale);
    // UV.y=0 is the attachment point; keeps stem/branch junction stationary.
    float anchor = smoothstep(0.05, 0.95, UV.y);
    float displacement = reduced_motion ? 0.0 : (gust * 0.72 + secondary * 0.28) * wind_strength * anchor;
    VERTEX.x += displacement;
    VERTEX.z += displacement * 0.42;
    wind_phase = displacement;
}

void fragment() {
    vec4 sampled = texture(leaf_albedo, UV);
    ALPHA = sampled.a * leaf_tint.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
    vec3 base = sampled.rgb * leaf_tint.rgb;
    ALBEDO = FRONT_FACING ? base : mix(base, underside_tint.rgb * sampled.rgb, 0.55);
    vec3 normal_sample = texture(leaf_normal, UV).rgb;
    NORMAL_MAP = normal_sample;
    NORMAL_MAP_DEPTH = normal_strength;
    ROUGHNESS = roughness_value;
    SPECULAR = 0.18;
    // Bounded transmission approximation, not physically measured leaf optics.
    BACKLIGHT = ALBEDO * translucency;
}
