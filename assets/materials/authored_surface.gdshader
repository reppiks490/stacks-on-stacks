shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

// Authored texture inputs. This shader does not generate substitute geometry.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 pigment : source_color = vec4(1.0);
uniform float uv_scale : hint_range(0.1, 16.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.7;
uniform float roughness_floor : hint_range(0.0, 1.0) = 0.38;
uniform float roughness_ceiling : hint_range(0.0, 1.0) = 0.94;
uniform float macro_variation : hint_range(0.0, 0.16) = 0.045;
uniform float macro_scale : hint_range(0.002, 0.3) = 0.035;
// World-space sampling prevents macro-pigment discontinuities between streamed chunks.
varying vec3 macro_world_position;

void vertex() {
    macro_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = UV * uv_scale;
    vec3 base = texture(albedo_map, uv).rgb * pigment.rgb;
    // Gentle, deterministic low-frequency tint; never replaces authored detail.
    vec2 macro_phase = macro_world_position.xz * macro_scale;
    // Suppress subpixel pigment oscillation at distance and oblique grazing angles.
    // fwidth is evaluated in fragment space; the attenuation is presentation-only.
    vec2 phase_footprint = fwidth(macro_phase);
    float macro_fade = 1.0 - smoothstep(0.5, 1.5, max(phase_footprint.x, phase_footprint.y));
    float macro = sin(macro_phase.x) * cos(macro_phase.y) * macro_fade;
    ALBEDO = clamp(base * (1.0 + macro * macro_variation), vec3(0.0), vec3(1.0));
    NORMAL_MAP = texture(normal_map, uv).rgb;
    NORMAL_MAP_DEPTH = normal_strength;
    float r = texture(roughness_map, uv).r;
    ROUGHNESS = mix(roughness_floor, roughness_ceiling, r);
    METALLIC = 0.0;
    SPECULAR = 0.42;
}
