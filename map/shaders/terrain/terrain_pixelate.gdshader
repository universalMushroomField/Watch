shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D opaque_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D opaque_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform int pixel_size : hint_range(1, 16, 1) = 4;

void fragment() {
	// 只覆盖上一遍实际写入深度的白模表面，崩解缺口保持贯通。
	float depth = textureLod(opaque_depth, SCREEN_UV, 0.0).r;
	if (pixel_size <= 1 || abs(depth - FRAGCOORD.z) > 0.000001) {
		discard;
	}
	float size = float(pixel_size);
	vec2 cell_center = floor(SCREEN_UV * VIEWPORT_SIZE / size) * size + floor(size * 0.5) + 0.5;
	vec2 sample_uv = min(cell_center, VIEWPORT_SIZE - 0.5) / VIEWPORT_SIZE;
	float sample_depth = textureLod(opaque_depth, sample_uv, 0.0).r;
	// 反向 Z：比当前面更近的颜色可能来自覆盖它的地点标记。
	if (sample_depth > depth + abs(dFdx(FRAGCOORD.z)) * size + abs(dFdy(FRAGCOORD.z)) * size + 0.000001) {
		discard;
	}
	ALBEDO = textureLod(opaque_color, sample_uv, 0.0).rgb;
	ALPHA = 1.0;
}
