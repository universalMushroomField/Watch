// 节点标记：始终正对相机的方形贴片，在片元里画环。
//
// 三种用途（见 map/scripts/map_highlight.gd 的 KIND_STYLE）：
//   可前往 —— 细实线环，轻微呼吸；
//   悬停   —— 更粗的环；
//   玩家所在 —— 实心圆底 + 旋转虚线环，配白色标签。
// 形状全部由 uniform 控制，呼吸与虚线用 TIME 直接算，节点侧不需要逐帧改参数。
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled;

// 环与描线的颜色；alpha 参与最终透明度。
uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 实心圆底的颜色（只在玩家所在节点用），radius 为 0 时不画。
uniform vec4 disc_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float disc_radius = 0.0;
uniform float disc_feather = 0.03;
// 环外的深色描边，保证浅色地表上也能看清。
uniform vec4 edge_color : source_color = vec4(0.25882353, 0.09019608, 0.00000000, 0.75);
// 主环半径，单位是贴片 UV（中心 0，贴片边缘 0.5）。
uniform float ring_radius = 0.4;
// 主环线宽，单位同上。
uniform float ring_width = 0.03;
// 内环半径与线宽；线宽为 0 时不画内环。
uniform float inner_ring_radius = 0.0;
uniform float inner_ring_width = 0.0;
// 深色描边的额外宽度。
uniform float edge_width = 0.008;
// 虚线段数；为 0 时画实线环。
uniform float dash_count = 0.0;
// 虚线绕环旋转的圈数（每秒）。
uniform float dash_speed = 0.0;
// 呼吸频率与幅度。
uniform float pulse_speed = 2.0;
uniform float pulse_amount = 0.04;
uniform float pulse_alpha = 0.35;
// 整体透明度。
uniform float opacity = 1.0;


// |d - radius| 落在 width 内时为 1，向外平滑衰减到 0。
float band(float distance_to_center, float radius, float width) {
	float offset = abs(distance_to_center - radius);
	return 1.0 - smoothstep(max(width * 0.5, 0.0001), max(width, 0.0002), offset);
}


void vertex() {
	// 贴片正对相机，同时保留节点自身的缩放（放大时标记跟着变大）。
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}


void fragment() {
	vec2 local = UV - vec2(0.5);
	float distance_to_center = length(local);
	float wave = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float radius = ring_radius * (1.0 + pulse_amount * wave);
	float breathe = mix(1.0, 1.0 - pulse_alpha, wave);

	float disc = 0.0;
	if (disc_radius > 0.0001) {
		disc = 1.0 - smoothstep(max(disc_radius - disc_feather, 0.0), disc_radius, distance_to_center);
	}

	float ring = band(distance_to_center, radius, ring_width);
	if (dash_count > 0.5) {
		float angle = atan(local.y, local.x);
		float dash = 0.5 + 0.5 * sin(angle * dash_count - TIME * dash_speed * 6.283185);
		ring *= smoothstep(0.2, 0.6, dash);
	}
	float inner = 0.0;
	if (inner_ring_width > 0.0001) {
		inner = band(distance_to_center, inner_ring_radius, inner_ring_width);
	}

	// 环压在圆底之上：先各自算颜色与不透明度，再按 over 合成一次。
	float stroke = max(ring, inner);
	float outline = band(distance_to_center, radius, ring_width + edge_width * 2.0) * (1.0 - disc);
	vec3 stroke_rgb = mix(edge_color.rgb, fill_color.rgb, stroke);
	float stroke_alpha = max(stroke * fill_color.a, outline * edge_color.a) * breathe;
	float disc_alpha = disc * disc_color.a;

	float total_alpha = stroke_alpha + disc_alpha * (1.0 - stroke_alpha);
	vec3 blended = total_alpha > 0.0001
		? (stroke_rgb * stroke_alpha + disc_color.rgb * disc_alpha * (1.0 - stroke_alpha)) / total_alpha
		: stroke_rgb;
	if (total_alpha <= 0.0001) {
		discard;
	}
	ALBEDO = blended;
	ALPHA = total_alpha * opacity;
}