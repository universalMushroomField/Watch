#include "res://shaders/include/viewport_edge_noise.gdshaderinc"

// 两个白模入口共用：根据视口边距和流动噪声判断是否裁剪片元。
bool terrain_edge_missing(vec2 screen_uv, vec2 viewport_size, float time, float p_edge_width, float p_block_size, float p_breakup, vec2 p_flow_direction, float p_flow_speed, float p_noise_detail, float p_contrast) {
    vec2 pixel = screen_uv * viewport_size;
    float band = p_edge_width * min(viewport_size.x, viewport_size.y);
    vec2 center = (floor(pixel / p_block_size) + 0.5) * p_block_size;
    vec2 edge_sample = mix(pixel, center, p_breakup);
    float edge_distance = distance_to_edge(edge_sample, viewport_size);

    if (edge_distance < band) {
        float coverage = smoothstep(0.0, band, edge_distance);
        float boundary = smoothstep(0.0, min(p_block_size, band * 0.3), edge_distance);
        float alpha = coverage * boundary;

        // —— 替换点：用流动 fbm 代替离散哈希 ——
        vec2 dir = normalize(p_flow_direction + vec2(0.0001));
        vec2 noise_uv = edge_sample / p_block_size + dir * time * p_flow_speed;
        float n = fbm(noise_uv, p_noise_detail);
        // 提高对比度，避免整片“糊成一团”
        n = clamp((n - 0.5) * p_contrast + 0.5, 0.0, 1.0);

        return alpha <= n;
    }
    return false;
}
