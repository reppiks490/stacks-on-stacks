shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Original EVERBLOOM soil surface: continuous furrow relief, moisture-darkened
// loam, mineral grains and micro-roughness. No imported textures or licenses.
// Bind to a subdivided plane or grid mesh with local UV spanning one bed.
uniform vec4 dry_loam : source_color = vec4(0.39, 0.235, 0.145, 1.0);
uniform vec4 wet_loam : source_color = vec4(0.18, 0.115, 0.083, 1.0);
uniform vec4 mineral_tint : source_color = vec4(0.59, 0.47, 0.32, 1.0);
uniform float moisture : hint_range(0.0, 1.0) = 0.35;
uniform float fertility : hint_range(0.0, 1.0) = 0.8;
uniform float tilled : hint_range(0.0, 1.0) = 1.0;
uniform float furrow_count : hint_range(2.0, 24.0) = 9.0;
uniform float furrow_height : hint_range(0.0, 0.075) = 0.028;
uniform float grain_scale : hint_range(8.0, 180.0) = 75.0;

varying vec2 bed_uv;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float relief(vec2 uv) {
    float irregularity = (value_noise(uv * 13.0) - 0.5) * 0.21;
    float ridge = pow(0.5 + 0.5 * cos((uv.x + irregularity) * furrow_count * 6.2831853), 2.0);
    return ridge * furrow_height * tilled;
}
void vertex() {
    bed_uv = UV;
    VERTEX.y += relief(UV);
}
void fragment() {
    vec2 uv = bed_uv;
    float coarse = value_noise(uv * 18.0);
    float fine = value_noise(uv * grain_scale);
    float mineral = smoothstep(0.72, 0.94, fine);
    float damp = clamp(moisture, 0.0, 1.0);
    vec3 base = mix(dry_loam.rgb, wet_loam.rgb, damp * 0.83);
    base *= mix(0.87, 1.12, coarse);
    base = mix(base, mineral_tint.rgb, mineral * (0.09 + 0.13 * (1.0 - damp)));
    base = mix(base, base * vec3(0.84, 0.96, 0.79), fertility * 0.075);
    float ridge = relief(uv) / max(furrow_height, 0.0001);
    base *= 0.91 + 0.13 * ridge;
    ALBEDO = base;
    ROUGHNESS = mix(0.96, 0.54, damp) + (fine - 0.5) * 0.11;
    SPECULAR = mix(0.19, 0.37, damp);
    // Fragment normal perturbation complements geometry; it does not alter collision.
    float nx = value_noise((uv + vec2(0.003, 0.0)) * grain_scale) - fine;
    float ny = value_noise((uv + vec2(0.0, 0.003)) * grain_scale) - fine;
    NORMAL_MAP = normalize(vec3(-nx * 4.0, -ny * 4.0, 1.0)) * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 0.28;
}
