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
// Bed margins taper naturally into the unchanged gameplay/collision footprint.
uniform float edge_fade : hint_range(0.01, 0.25) = 0.095;
uniform float micro_relief : hint_range(0.0, 0.012) = 0.004;
// Physical dimensions of the existing bed top, used for tangent-space slopes.
uniform vec2 bed_size = vec2(1.48, 1.48);

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
    float edge = smoothstep(0.0, edge_fade, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
    float clods = (value_noise(uv * 43.0) - 0.5) * micro_relief;
    return (ridge * furrow_height + clods) * tilled * edge;
}
void vertex() {
    bed_uv = UV;
    VERTEX.y += relief(UV);
}
void fragment() {
    vec2 uv = bed_uv;
    float coarse = value_noise(uv * 18.0);
    // Filter high-frequency mineral grains to prevent subpixel sparkle as the camera recedes.
    // fwidth is evaluated in fragment space; no extra texture or asset dependency.
    float grain_footprint = max(fwidth(uv.x), fwidth(uv.y)) * grain_scale;
    float grain_visibility = 1.0 - smoothstep(0.32, 1.2, grain_footprint);
    float fine = mix(0.5, value_noise(uv * grain_scale), grain_visibility);
    float mineral = smoothstep(0.72, 0.94, fine);
    // Localized capillary dampness follows troughs and low-frequency soil pockets.
    // This is a visual approximation; authoritative soil water remains in farm.gd.
    float trough = 1.0 - clamp(relief(uv) / max(furrow_height, 0.0001), 0.0, 1.0);
    float pockets = value_noise(uv * 7.0 + vec2(13.0, 5.0));
    float damp = clamp(moisture + (trough * 0.10 + (pockets - 0.5) * 0.16) * moisture, 0.0, 1.0);
    vec3 base = mix(dry_loam.rgb, wet_loam.rgb, damp * 0.83);
    base *= mix(0.87, 1.12, coarse);
    base = mix(base, mineral_tint.rgb, mineral * (0.09 + 0.13 * (1.0 - damp)));
    base = mix(base, base * vec3(0.84, 0.96, 0.79), fertility * 0.075);
    float ridge = relief(uv) / max(furrow_height, 0.0001);
    base *= 0.91 + 0.13 * ridge;
    ALBEDO = base;
    ROUGHNESS = clamp(mix(0.96, 0.54, damp) + (fine - 0.5) * 0.11, 0.45, 1.0);
    SPECULAR = mix(0.19, 0.37, damp);
    // Fragment normal perturbation complements geometry; it does not alter collision.
    // Match displaced furrow geometry with a finite-difference tangent normal.
    // A small grain component provides sub-vertex detail without replacing the
    // large-scale slope. Geometry/collision remain independently authored.
    // Use a pixel-aware derivative step so fine ridge normals do not alias when
    // furrows approach subpixel width. Keep displacement unchanged.
    float eps = 0.002;
    float pixel_uv = max(fwidth(uv.x), fwidth(uv.y));
    float normal_step = clamp(max(eps, pixel_uv * 0.5), eps, 0.04);
    vec2 du = vec2(normal_step, 0.0);
    vec2 dv = vec2(0.0, normal_step);
    // Clamp to the authored bed footprint; sampling outside [0,1] at its
    // boundary would otherwise produce false slopes and edge highlights.
    // At UV borders the stencil is one-sided: divide by the actual sampled
    // distance, not 2*h, or normals become artificially flattened at edges.
    vec2 uv_x0 = clamp(uv - du, vec2(0.0), vec2(1.0));
    vec2 uv_x1 = clamp(uv + du, vec2(0.0), vec2(1.0));
    vec2 uv_y0 = clamp(uv - dv, vec2(0.0), vec2(1.0));
    vec2 uv_y1 = clamp(uv + dv, vec2(0.0), vec2(1.0));
    float dh_du = (relief(uv_x1) - relief(uv_x0)) / (max(uv_x1.x - uv_x0.x, 0.00001) * max(bed_size.x, 0.01));
    float dh_dv = (relief(uv_y1) - relief(uv_y0)) / (max(uv_y1.y - uv_y0.y, 0.00001) * max(bed_size.y, 0.01));
    // Fade micro-normal detail at distance as well; unfiltered high-frequency normals
    // shimmer even when the corresponding albedo grains have been filtered.
    float grain_du = (value_noise((uv + du) * grain_scale) - value_noise((uv - du) * grain_scale)) * grain_visibility * (eps / normal_step);
    float grain_dv = (value_noise((uv + dv) * grain_scale) - value_noise((uv - dv) * grain_scale)) * grain_visibility * (eps / normal_step);
    vec3 soil_normal = normalize(vec3(-dh_du - grain_du * 0.06, -dh_dv - grain_dv * 0.06, 1.0));
    NORMAL_MAP = soil_normal * 0.5 + 0.5;
    NORMAL_MAP_DEPTH = 1.0;
}
