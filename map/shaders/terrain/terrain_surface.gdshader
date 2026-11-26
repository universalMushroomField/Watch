// 白模的主绘制通道：在视口边带内按流动噪声裁剪片元，并把受光强度量化成分阶亮度。
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
// Columns are lighting bands; rows run from red through four mixes to blue.
uniform sampler2D region_palette : source_color, filter_nearest, repeat_disable;
uniform float region_transition_width : hint_range(0.1, 8.0, 0.1) = 2.0;
uniform float region_flow_speed : hint_range(0.0, 4.0, 0.05) = 0.65;
// Each texel stores a node's world XZ and its visited flag.
uniform sampler2D region_nodes : filter_nearest, repeat_disable;
uniform int region_node_count = 0;
varying vec2 world_xz;
varying flat int palette_row;
/** 崩解边带占视口短边的比例，值越大，效果越靠近画面中央。 */
uniform float edge_width : hint_range(0.02, 0.45, 0.01) = 0.17;
/** 边缘噪声方格的边长，单位为屏幕像素。 */
uniform float block_size : hint_range(1.0, 64.0, 1.0) = 12.0;
/** 从逐像素采样过渡到方格中心采样的比例，设为 1 时整格同时显隐。 */
uniform float breakup : hint_range(0.0, 1.0, 0.01) = 0.8;

// —— 流动控制 ——
/** 噪声在屏幕平面中的采样方向，两个分量对应横向和纵向。 */
uniform vec2 flow_direction = vec2(0.6, 0.8);           // 流动方向（自动归一化）
/** 动画时间倍率，设为 0 可静止预览。 */
uniform float flow_speed : hint_range(0.0, 5.0, 0.01) = 0.5;
/** 叠加的噪声层数，较多层会增加细节和采样开销。 */
uniform float noise_detail : hint_range(1.0, 4.0, 1.0) = 2.0;
/** 噪声围绕中间值的对比度，值越大，亮暗分区越明显。 */
uniform float contrast : hint_range(0.5, 4.0, 0.1) = 1.5;

#include "res://map/shaders/terrain/terrain_surface.gdshaderinc"

void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

vec3 region_color(int band, int row) {
    return texelFetch(region_palette, ivec2(band, row), 0).rgb;
}

// 在边带内比较覆盖率与流动噪声，保留的白模片元接受光照和补光。
void fragment() {
    if (terrain_edge_missing(SCREEN_UV, VIEWPORT_SIZE, TIME, edge_width, block_size, breakup,
            flow_direction, flow_speed, noise_detail, contrast)) {
        discard;
    }

    vec2 nearest = vec2(1e20);
    for (int i = 0; i < region_node_count; i++) {
        vec3 node = texelFetch(region_nodes, ivec2(i, 0), 0).rgb;
        vec2 offset = world_xz - node.xy;
        int team = int(node.z);
        nearest[team] = min(nearest[team], dot(offset, offset));
    }
    float signed_distance = sqrt(nearest.x) - sqrt(nearest.y);
    float phase = TIME * region_flow_speed;
    float wave = sin(dot(world_xz, vec2(1.35, 0.85)) - phase);
    wave += 0.45 * sin(dot(world_xz, vec2(-0.65, 1.6)) + phase * 0.7);
    float half_width = region_transition_width * 0.5;
    float blend = smoothstep(-half_width, half_width,
            signed_distance + wave * half_width * 0.3);
    palette_row = region_node_count == 0 ? 0 : int(floor(blend * 5.0 + 0.5));
    ALBEDO = vec3(1.0);
    EMISSION = region_color(0, palette_row);
}

void light() {
    float illumination = clamp(dot(NORMAL, LIGHT) * ATTENUATION, 0.0, 1.0);
    int band = min(int(illumination * 6.0), 5);
    DIFFUSE_LIGHT += region_color(band, palette_row) - region_color(0, palette_row);
}
