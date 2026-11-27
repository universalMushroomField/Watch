// 视口边缘噪声库。输入屏幕坐标和采样参数，返回噪声或边距。
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
