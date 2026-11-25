// 地形外扩轮廓通道，共享碎块位移与侵蚀判定。
shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never, shadows_disabled;
/** 启用当前实例顶点色中编码的体素深度和碎块标记。 */
instance uniform bool use_voxel_depth : instance_index(0) = false;
/** 动画时间倍率，设为 0 可静止预览。 */
instance uniform float flow_speed : instance_index(1), hint_range(0.0, 3.0) = 0.65;
/** 独立碎块沿局部负 Y 轴下沉的最大距离。 */
instance uniform float fall_distance : instance_index(2), hint_range(0.0, 3.0) = 0.95;

// 独立碎石共用整块相位。缓慢蓄势后下沉，错开回浮的时机。
// 从体素颜色读取活动标记、埋深和相位，返回向下位移的距离。
float debris_drop(vec4 cell, float time) {
	if (!use_voxel_depth || cell.g < 0.5) {
		return 0.0;
	}
	float cycle = fract(time * flow_speed * 0.23 + cell.b);
	float drop = smoothstep(0.18, 0.60, cycle) * (1.0 - smoothstep(0.68, 1.0, cycle));
	return drop * fall_distance * cell.r;
}
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

// 沿真实断面外扩一层，深度测试保留露在实体轮廓外的部分。
/** 外扩轮廓的颜色和不透明度。 */
uniform vec4 outline_color : source_color = vec4(0.27, 0.82, 0.96, 0.48);
/** 沿模型法线外扩的宽度，体素表层使用较窄的轮廓。 */
uniform float outline_width : hint_range(0.0, 0.3, 0.005) = 0.045;
/** 无光照轮廓的颜色亮度倍率。 */
uniform float emission_strength : hint_range(0.0, 3.0, 0.05) = 1.15;

// 记录外扩前的采样位置，使轮廓跟随碎块下沉并沿法线扩张。
void vertex() {
	intact_position = VERTEX - NORMAL * 0.0001;
	VERTEX.y -= debris_drop(COLOR, TIME);
	float width = use_voxel_depth ? mix(0.2, 1.0, step(0.22, COLOR.r)) : 1.0;
	VERTEX += NORMAL * outline_width * width;
}

// 剔除侵蚀样本，再绘制半透明轮廓。
void fragment() {
	if (terrain_sample_missing(intact_position, use_voxel_depth ? COLOR.r : 0.0, TIME)) {
		discard;
	}
	ALBEDO = outline_color.rgb * emission_strength;
	ALPHA = outline_color.a;
}
