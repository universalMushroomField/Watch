uniform vec4 terrain_color : source_color = vec4(1.0);
uniform float edge_width : hint_range(0.02, 0.45, 0.01) = 0.17;
uniform float block_size : hint_range(1.0, 64.0, 1.0) = 12.0;
uniform float breakup : hint_range(0.0, 1.0, 0.01) = 0.8;

// —— 流动控制 ——
uniform vec2 flow_direction = vec2(0.6, 0.8);           // 流动方向（自动归一化）
uniform float flow_speed : hint_range(0.0, 5.0, 0.01) = 0.5;
uniform float noise_detail : hint_range(1.0, 4.0, 1.0) = 2.0;
uniform float contrast : hint_range(0.5, 4.0, 0.1) = 1.5;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 平滑插值的值噪声：相邻格子之间连续过渡
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

float distance_to_edge(vec2 pixel, vec2 viewport_size) {
    vec2 margin = min(pixel, viewport_size - pixel);
    return min(margin.x, margin.y);
}

void fragment() {
    vec2 pixel = SCREEN_UV * VIEWPORT_SIZE;
    float band = edge_width * min(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y);
    float edge_distance = distance_to_edge(pixel, VIEWPORT_SIZE);

    if (edge_distance < band) {
        // 边缘形状：保留原来的方块化采样 + breakup
        vec2 cell = floor(pixel / block_size);
        vec2 center = (cell + 0.5) * block_size;
        float cell_distance = max(0.0, distance_to_edge(center, VIEWPORT_SIZE));
        float sample_distance = mix(edge_distance, cell_distance, breakup);

        float coverage = smoothstep(0.0, band, sample_distance);
        float boundary = smoothstep(0.0, min(block_size, band * 0.3), edge_distance);
        float alpha = coverage * boundary;

        // —— 替换点：用流动 fbm 代替离散哈希 ——
        vec2 dir = normalize(flow_direction + vec2(0.0001));
        vec2 noise_uv = pixel / block_size + dir * TIME * flow_speed;
        float n = fbm(noise_uv, noise_detail);
        // 提高对比度，避免整片“糊成一团”
        n = clamp((n - 0.5) * contrast + 0.5, 0.0, 1.0);

        if (alpha <= n) discard;
    }

    ALBEDO = terrain_color.rgb;
    EMISSION = terrain_color.rgb * 0.14;
}
