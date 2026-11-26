shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
// Columns are lighting bands; rows select neutral, biological or human colors.
uniform sampler2D region_palette : source_color, filter_nearest, repeat_disable;
uniform float region_radius : hint_range(0.1, 8.0, 0.1) = 1.8;
uniform float root_reach : hint_range(0.0, 24.0, 0.25) = 12.0;
uniform float root_spacing : hint_range(1.0, 8.0, 0.1) = 3.8;
// Row 0 stores world XZ endpoints; row 1 stores the team. Isolated nodes have coincident endpoints.
uniform sampler2D region_spans : filter_nearest, repeat_disable;
uniform int region_span_count = 0;
varying vec2 world_xz;
varying flat int palette_row;
group_uniforms ViewportBreakup;
/** Width of each side band as a fraction of the viewport width. */
uniform float breakup_width : hint_range(0.0, 0.5, 0.01) = 0.25;
uniform float breakup_strength : hint_range(0.0, 1.0, 0.01) = 0.85;
/** Size of a breakup cell in viewport pixels. */
uniform float fragment_pixels : hint_range(1.0, 32.0, 1.0) = 4.0;
/** 噪声每秒移动的格数。 */
uniform float flow_speed : hint_range(0.0, 3.0, 0.05) = 0.25;
group_uniforms;
#include "res://map/shaders/terrain/terrain_surface.gdshaderinc"

void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec3 region_color(int band, int row) {
    return texelFetch(region_palette, ivec2(band, row), 0).rgb;
}

// 在边带内比较覆盖率与流动噪声，保留的白模片元接受光照和补光。
// Bent cell boundaries form continuous filaments with three-way junctions.
float root_edge_distance(vec2 position) {
    vec2 p = position / root_spacing;
    p += 0.27 * sin(p.yx * 2.3) + 0.11 * sin(p.yx * 4.7 + 1.3);
    vec2 closest = vec2(8.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 id = floor(p) + offset;
            vec2 jitter = fract(sin(vec2(dot(id, vec2(127.1, 311.7)),
                    dot(id, vec2(269.5, 183.3)))) * 4375.5);
            vec2 delta = offset + 0.25 + 0.5 * jitter - fract(p);
            float d = dot(delta, delta);
            closest = vec2(min(closest.x, d), min(closest.y, max(closest.x, d)));
        }
    }
    return closest.y - closest.x;
}

void fragment() {
    if (side_cell_missing(SCREEN_UV, VIEWPORT_SIZE, TIME)) {
        discard;
    }

    vec2 nearest = vec2(1e20);
    vec2 node_distance = vec2(1e20);
    bool inside = false;
    for (int i = 0; i < region_span_count; i++) {
        vec4 span = texelFetch(region_spans, ivec2(i, 0), 0);
        vec2 axis = span.zw - span.xy;
        vec2 offset = world_xz - span.xy;
        float along = clamp(dot(offset, axis) / max(dot(axis, axis), 0.00001), 0.0, 1.0);
        offset -= along * axis;
        vec3 metadata = texelFetch(region_spans, ivec2(i, 1), 0).rgb;
        int team = int(metadata.r);
        float d2 = dot(offset, offset);
        nearest[team] = min(nearest[team], d2);
        if (metadata.g < 0.5) {
            node_distance[team] = min(node_distance[team], d2);
        } else {
            if ((span.y > world_xz.y) != (span.w > world_xz.y)) {
                float crossing = span.x + (world_xz.y - span.y) * axis.x / axis.y;
                if (world_xz.x < crossing) { inside = !inside; }
            }
            if (metadata.b > 0.5) {
                if (inside) { nearest[team] = 0.0; }
                inside = false;
            }
        }
    }
    vec2 dist = sqrt(nearest);
    float human = 1.0 - smoothstep(region_radius * 0.35, region_radius, dist.y);
    float biological = 1.0 - smoothstep(0.0, region_radius, dist.x);
    if (dist.x > 0.0 && dist.x < region_radius + root_reach && root_reach > 0.0) {
        float clearance = smoothstep(0.0, region_radius * 2.0, dist.y - dist.x);
        float reach = region_radius + root_reach * clearance;
        float taper = 1.0 - smoothstep(0.0, reach, dist.x);
        float edge = root_edge_distance(world_xz);
        float trunk = 1.0 - smoothstep(0.016, 0.21, edge);
        float fine_edge = root_edge_distance(world_xz * 2.1 + vec2(7.3, 2.9));
        float branch = 1.0 - smoothstep(0.012, 0.18, fine_edge);
        branch *= 0.85 * (1.0 - smoothstep(0.22, 0.78, edge));
        biological = max(biological, max(trunk, branch) * taper * clearance);
    }
    if (max(dist.x, dist.y) < region_radius) {
        float front = sqrt(node_distance.y) - sqrt(node_distance.x);
        biological *= smoothstep(0.0, region_radius, front);
        human *= smoothstep(0.0, region_radius, -front);
    }
    palette_row = 0;
    if (human > 0.08) {
        palette_row = human > 0.58 ? 5 : 4;
    } else if (biological > 0.08) {
        palette_row = biological > 0.7 ? 3 : (biological > 0.32 ? 2 : 1);
    }
    ALBEDO = vec3(1.0);
    EMISSION = region_color(0, palette_row);
}

void light() {
    float illumination = clamp(dot(NORMAL, LIGHT) * ATTENUATION, 0.0, 1.0);
    // Reserve the brightest palette entries for markers over the terrain.
    int band = min(int(illumination * 4.5), 4);
    DIFFUSE_LIGHT += region_color(band, palette_row) - region_color(0, palette_row);
}
