shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 wall_color : source_color = vec4(0.62, 0.70, 0.80, 1.0);
uniform vec4 top_color : source_color = vec4(0.88, 0.93, 1.0, 1.0);
uniform float emissive = 0.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	float height = clamp(UV.y, 0.0, 1.0);
	vec3 color = mix(wall_color.rgb, top_color.rgb, smoothstep(0.0, 1.0, height));
	// 底边压暗，让墙脚自然融进地形，顶边保持明亮。
	ALBEDO = color * mix(0.45, 1.0, height);
	// 墙脚保留半透明，越靠近墙顶越透明，最后在墙顶完全消失。
	ALPHA = base_alpha * (1.0 - 0.6 * smoothstep(0.0, 1.0, height));
	EMISSION = color * emissive * (1.0 - height * 0.65);
}
