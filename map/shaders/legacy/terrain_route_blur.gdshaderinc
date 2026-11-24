// 在六边形路线附近给底模加一层很轻的屏幕模糊，让白模路线从地形里浮出来。
// 这层网格和地形共用同一个 mesh，晚于地形、早于路线圆管/标签绘制。
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back, shadows_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// 由 MapHexLayer 生成的路线遮罩：白色表示靠近六边形边/顶点。
uniform sampler2D route_mask : source_color, filter_linear, repeat_disable;
uniform vec2 mask_min = vec2(-25.6, -25.6);
uniform vec2 mask_size = vec2(51.2, 51.2);
uniform float blur_strength : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform vec2 blur_pixels = vec2(2.0, 2.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 screen_uv = SCREEN_UV;
	vec2 pixel = blur_pixels / VIEWPORT_SIZE;
	vec3 color = texture(screen_texture, screen_uv).rgb * 0.20;
	color += texture(screen_texture, screen_uv + vec2(pixel.x, 0.0)).rgb * 0.10;
	color += texture(screen_texture, screen_uv - vec2(pixel.x, 0.0)).rgb * 0.10;
	color += texture(screen_texture, screen_uv + vec2(0.0, pixel.y)).rgb * 0.10;
	color += texture(screen_texture, screen_uv - vec2(0.0, pixel.y)).rgb * 0.10;
	color += texture(screen_texture, screen_uv + pixel).rgb * 0.10;
	color += texture(screen_texture, screen_uv + vec2(pixel.x, -pixel.y)).rgb * 0.10;
	color += texture(screen_texture, screen_uv + vec2(-pixel.x, pixel.y)).rgb * 0.10;
	color += texture(screen_texture, screen_uv - pixel).rgb * 0.10;

	vec2 mask_uv = (world_pos.xz - mask_min) / mask_size;
	float mask = texture(route_mask, mask_uv).r;
	ALBEDO = color;
	ALPHA = mask * blur_strength;
}