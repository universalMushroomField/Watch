shader_type spatial;
render_mode cull_back;

uniform vec4 terrain_color : source_color = vec4(1.0);
uniform float edge_width : hint_range(0.02, 0.45, 0.01) = 0.17;
uniform float block_size : hint_range(2.0, 64.0, 1.0) = 12.0;
uniform float breakup : hint_range(0.0, 1.0, 0.01) = 0.8;

float cell_noise(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
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
		if (coverage * boundary <= cell_noise(cell)) {
			discard;
		}
	}
	ALBEDO = terrain_color.rgb;
}