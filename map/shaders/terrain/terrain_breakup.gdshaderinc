#include "res://shaders/include/noise_3d.gdshaderinc"

group_uniforms Breakup;
// 模型局部空间中的连续噪声频率。
uniform float breakup_noise_scale : hint_range(0.0001, 4.0, 0.001) = 0.27;
// 缺口边缘的台阶宽度（模型单位）。设为 0 可恢复连续轮廓。
uniform float breakup_edge_pixel_size : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform float breakup_strength : hint_range(0.0, 1.0) = 0.65;
uniform float breakup_transparency : hint_range(0.0, 1.0, 0.01) = 0.65;
uniform float breakup_speed : hint_range(0.0, 3.0) = 0.45;
group_uniforms;
varying vec3 intact_position;

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

bool terrain_sample_missing(vec3 position, float depth, float time) {
	if (breakup_transparency <= 0.0 || !terrain_is_eroded(position, depth, time)) {
		return false;
	}
	// 固定在模型上的细粒覆盖率，保留的样本写入深度，避免双面透明网格排序。
	return noise_white_3d(floor(position / 0.055)) < breakup_transparency;
}
