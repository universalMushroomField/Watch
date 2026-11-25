#include "res://shaders/include/noise_3d.gdshaderinc"

// 根据局部位置、相对埋深和时间判断当前样本是否进入侵蚀区。
bool terrain_is_eroded(vec3 position, float depth, float time) {
	if (breakup_strength <= 0.0) {
		return false;
	}
	vec3 drift = vec3(0.26, 0.9, -0.34) * time * breakup_speed;
	vec3 sample_position = position;
	if (breakup_edge_pixel_size > 0.0) {
		sample_position = (floor(position / breakup_edge_pixel_size) + 0.5) * breakup_edge_pixel_size;
	}
	float field = noise_fbm_3d(sample_position * breakup_noise_scale + drift);
	return field < breakup_strength * mix(0.44, 0.86, depth);
}

// 在侵蚀区按透明度选择要丢弃的模型空间样本。
bool terrain_sample_missing(vec3 position, float depth, float time) {
	if (breakup_transparency <= 0.0 || !terrain_is_eroded(position, depth, time)) {
		return false;
	}
	// 固定在模型上的细粒覆盖率，保留的样本写入深度，避免双面透明网格排序。
	return noise_white_3d(floor(position / 0.055)) < breakup_transparency;
}
