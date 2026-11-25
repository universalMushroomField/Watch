// 交互路线的像素化通道，以屏幕方格中心判定路线覆盖范围。
/** 屏幕采样格边长，单位为像素。 */
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
/** 交互路径的颜色，透明通道控制路线的不透明度。 */
uniform vec4 pixel_color : source_color = vec4(0.12, 0.75, 0.70, 0.65);

// 扩大线带在裁剪空间的边距，为像素格采样留出空间。
void vertex() {
	// Expand the overlay so grid cells can extend past the original ribbon.
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 side = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(NORMAL, 0.0);
	vec2 projected_side = (side.xy * clip.w - clip.xy * side.w) * VIEWPORT_SIZE;
	vec2 direction = projected_side / max(length(projected_side), 0.0001);
	clip.xy += direction * (UV.y * 2.0 - 1.0) * pixel_size * 2.0 * clip.w / VIEWPORT_SIZE;
	POSITION = clip;
}

// 将屏幕格心还原到线带 UV，裁掉线宽和端点以外的片元。
void fragment() {
	// Classify the whole screen cell by its center rather than the current fragment.
	vec2 pixel = SCREEN_UV * VIEWPORT_SIZE;
	vec2 cell_center = (floor(pixel / pixel_size) + 0.5) * pixel_size;
	vec2 offset = cell_center - pixel;
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	vec2 sampled = UV + dx * offset.x + dy * offset.y;
	float uv_per_pixel = max(length(vec2(dx.y, dy.y)), 0.00001);
	// 扣除顶点阶段为方格采样增加的边距，线宽由路线本身决定。
	float half_width = max(0.5 / uv_per_pixel - pixel_size, 0.5 * pixel_size);
	if (sampled.x < 0.0 || sampled.x > 1.0 || abs(sampled.y - 0.5) > half_width * uv_per_pixel) {
		discard;
	}
	ALBEDO = pixel_color.rgb;
	ALPHA = pixel_color.a;
}
