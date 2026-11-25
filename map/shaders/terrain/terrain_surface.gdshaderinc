// 白模的主绘制通道，在视口边带内按流动噪声裁剪片元。
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

// 将二维格点映射为可重复的标量随机值。
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 平滑插值的值噪声：相邻格子之间连续过渡
// 插值周围四个格点的随机值，返回连续的二维值噪声。
float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);   // smoothstep 插值
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// fbm：多层噪声叠加，层次更丰富
// 按层提高采样频率并降低振幅，累加二维分形噪声。
float fbm(vec2 p, float detail) {
    float v = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < 4; i++) {
        if (float(i) >= detail) break;
        v += value_noise(p * freq) * amp;
        freq *= 2.0;
        amp *= 0.5;
    }
    return v;
}

// 返回屏幕位置距最近一条视口边界的像素距离。
float distance_to_edge(vec2 pixel, vec2 viewport_size) {
    vec2 margin = min(pixel, viewport_size - pixel);
    return min(margin.x, margin.y);
}

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
