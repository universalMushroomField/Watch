// 体素碎块动画库，读取实例参数与顶点色，计算局部下沉量。
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
