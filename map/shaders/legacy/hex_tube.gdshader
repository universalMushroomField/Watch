// 旧版圆管路线材质，按与地表的深度差柔化遮挡。
shader_type spatial;
// 白色网格线：受光、半透明，并按场景深度柔化被地形挡住的边缘。
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

/** 表面的基础着色，用于计算受光颜色和暗部补光。 */
uniform vec3 base_color : source_color = vec3(0.98, 0.98, 0.98);
// 完全可见到完全淡出的深度差（米）。
/** 从此遮挡深度差开始淡出圆管线，单位为米。 */
uniform float fade_near = 0.04;
/** 达到此遮挡深度差时圆管线完全淡出，单位为米。 */
uniform float fade_far = 0.55;
/** 场景深度纹理，用于比较圆管线与地形的视空间距离。 */
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// 重建场景深度，按遮挡距离衰减圆管线的不透明度。
void fragment() {
	// 场景深度（不含这条半透明网格线本身）。
	float raw_depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV, raw_depth) * 2.0 - 1.0;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	float scene_distance = -scene_view.z;
	float fragment_distance = -VERTEX.z;
	float delta = fragment_distance - scene_distance;

	// 网格线在地形前面时 delta <= 0，完全显示；钻到地形后面时逐渐淡出，
	// 让硬切边变成一段柔和的过渡。
	float visibility = 1.0 - smoothstep(fade_near, fade_far, delta);
	// 白模：保留灯光造成的明暗，再补一层自发光，避免侧面在白色地形上过暗。
	ALBEDO = base_color;
	ROUGHNESS = 0.85;
	EMISSION = base_color * 0.38;
	ALPHA = visibility;
}
