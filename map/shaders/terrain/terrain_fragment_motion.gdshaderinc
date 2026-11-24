instance uniform bool use_voxel_depth : instance_index(0) = false;
instance uniform float flow_speed : instance_index(1), hint_range(0.0, 3.0) = 0.65;
instance uniform float fall_distance : instance_index(2), hint_range(0.0, 3.0) = 0.95;

// 独立碎石共用整块相位。缓慢蓄势后下沉，错开回浮的时机。
float debris_drop(vec4 cell, float time) {
	if (!use_voxel_depth || cell.g < 0.5) {
		return 0.0;
	}
	float cycle = fract(time * flow_speed * 0.23 + cell.b);
	float drop = smoothstep(0.18, 0.60, cycle) * (1.0 - smoothstep(0.68, 1.0, cycle));
	return drop * fall_distance * cell.r;
}
