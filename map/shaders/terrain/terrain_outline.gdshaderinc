#include "res://map/shaders/terrain/terrain_fragment_motion.gdshaderinc"
#include "res://map/shaders/terrain/terrain_breakup.gdshaderinc"

// 沿真实断面外扩一层，深度测试保留露在实体轮廓外的部分。
uniform vec4 outline_color : source_color = vec4(0.27, 0.82, 0.96, 0.48);
uniform float outline_width : hint_range(0.0, 0.3, 0.005) = 0.045;
uniform float emission_strength : hint_range(0.0, 3.0, 0.05) = 1.15;

void vertex() {
	intact_position = VERTEX - NORMAL * 0.0001;
	VERTEX.y -= debris_drop(COLOR, TIME);
	float width = use_voxel_depth ? mix(0.2, 1.0, step(0.22, COLOR.r)) : 1.0;
	VERTEX += NORMAL * outline_width * width;
}

void fragment() {
	if (terrain_sample_missing(intact_position, use_voxel_depth ? COLOR.r : 0.0, TIME)) {
		discard;
	}
	ALBEDO = outline_color.rgb * emission_strength;
	ALPHA = outline_color.a;
}
