// 模型空间侵蚀库，为地形材质提供深度遮罩和透明覆盖判定。
#include "res://shaders/include/noise_3d.gdshaderinc"

group_uniforms Breakup;
// 模型局部空间中的连续噪声频率。
/** 模型空间噪声频率，值越小，缺口越容易连成大片。 */
uniform float breakup_noise_scale : hint_range(0.0001, 4.0, 0.001) = 0.27;
// 缺口边缘的台阶宽度（模型单位）。设为 0 可恢复连续轮廓。
/** 模型空间中缺口边缘的台阶宽度，设为 0 使用连续坐标。 */
uniform float breakup_edge_pixel_size : hint_range(0.0, 1.0, 0.01) = 0.16;
/** 深度侵蚀阈值的倍率，设为 0 关闭表面侵蚀。 */
uniform float breakup_strength : hint_range(0.0, 1.0) = 0.65;
/** 已侵蚀区域中丢弃的样本比例，设为 1 完全透明。 */
uniform float breakup_transparency : hint_range(0.0, 1.0, 0.01) = 0.65;
/** 噪声在模型空间中的流动速度，设为 0 得到静态图案。 */
uniform float breakup_speed : hint_range(0.0, 3.0) = 0.45;
group_uniforms;
varying vec3 intact_position;

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
