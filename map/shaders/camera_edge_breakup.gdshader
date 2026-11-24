shader_type spatial;
render_mode cull_back, depth_prepass_alpha, depth_prepass_alpha;

uniform vec4 terrain_color : source_color = vec4(1.0);
uniform float edge_width : hint_range(0.02, 0.45, 0.01) = 0.17;
uniform float block_size : hint_range(1.0, 64.0, 1.0) = 12.0;
uniform float breakup : hint_range(0.0, 1.0, 0.01) = 0.8;

// 新增：抖动刷新控制
uniform float random_speed : hint_range(1.0, 120.0) = 60.0;
uniform float refresh_probability : hint_range(0.0, 1.0) = 0.1;

// 抗大坐标的均匀哈希
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash_seed(vec2 p, float s) {
	return hash12(p + vec2(s * 0.137, s * 0.291));
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
		vec2 cell = floor(pixel / block_size);
		vec2 center = (cell + 0.5) * block_size;
		float cell_distance = max(0.0, distance_to_edge(center, VIEWPORT_SIZE));
		float sample_distance = mix(edge_distance, cell_distance, breakup);

		float coverage = smoothstep(0.0, band, sample_distance);
		float boundary = smoothstep(0.0, min(block_size, band * 0.3), edge_distance);

		// 原本的 alpha 语义：越靠边越小，内部为 1
		float alpha = coverage * boundary;

		// —— 替换点：每 cell 独立相位 + 帧节拍 ——
		float frame = floor(TIME * random_speed);
		float phase = hash12(cell + vec2(13.7, 71.3));
		float cycle = floor(frame * refresh_probability + phase);
		float r = hash_seed(cell, cycle);

		if (r >= alpha) discard;
	}

	ALBEDO = terrain_color.rgb;
}