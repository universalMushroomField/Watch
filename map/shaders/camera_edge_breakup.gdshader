// 旧版视口崩解入口，与地形主通道共享实现。
// 兼容旧资源路径。
shader_type spatial;
render_mode cull_disabled, specular_disabled;
/** 底模的基础颜色，也用于背光面的补光。 */
uniform vec4 terrain_color : source_color = vec4(1.0);
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

#include "res://shaders/include/viewport_edge_noise.gdshaderinc"

// 在边带内比较覆盖率与流动噪声，保留的白模片元接受光照和补光。
void fragment() {
    vec2 pixel = SCREEN_UV * VIEWPORT_SIZE;
    float band = edge_width * min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
    vec2 center = (floor(pixel / block_size) + 0.5) * block_size;
    vec2 edge_sample = mix(pixel, center, breakup);
    float edge_distance = distance_to_edge(edge_sample, VIEWPORT_SIZE);

    if (edge_distance < band) {
        float coverage = smoothstep(0.0, band, edge_distance);
        float boundary = smoothstep(0.0, min(block_size, band * 0.3), edge_distance);
        float alpha = coverage * boundary;

        // —— 替换点：用流动 fbm 代替离散哈希 ——
        vec2 dir = normalize(flow_direction + vec2(0.0001));
        vec2 noise_uv = edge_sample / block_size + dir * TIME * flow_speed;
        float n = fbm(noise_uv, noise_detail);
        // 提高对比度，避免整片“糊成一团”
        n = clamp((n - 0.5) * contrast + 0.5, 0.0, 1.0);

        if (alpha <= n) discard;
    }

    ALBEDO = terrain_color.rgb;
    EMISSION = terrain_color.rgb * 0.14;
}
