// 白模的主绘制通道，在视口边带内按流动噪声裁剪片元。
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

#include "res://map/shaders/terrain/terrain_surface.gdshaderinc"

// 在边带内比较覆盖率与流动噪声，保留的白模片元接受光照和补光。
void fragment() {
    if (terrain_edge_missing(SCREEN_UV, VIEWPORT_SIZE, TIME, edge_width, block_size, breakup,
            flow_direction, flow_speed, noise_detail, contrast)) {
        discard;
    }

    ALBEDO = terrain_color.rgb;
    EMISSION = terrain_color.rgb * 0.14;
}
