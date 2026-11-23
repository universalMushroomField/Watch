shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 tile_color : source_color = vec4(0.36, 0.55, 0.82, 1.0);
uniform vec4 border_color : source_color = vec4(0.95, 0.82, 0.45, 1.0);
uniform float border_width : hint_range(0.0, 0.5, 0.005) = 0.085;
uniform float emissive : hint_range(0.0, 3.0, 0.01) = 0.0;

const float HALF_SQRT3 = 0.8660254;

varying float v_top;

void vertex() {
	// 单位六边形的顶面法线朝上，侧面法线水平。
	v_top = step(0.5, NORMAL.y);
}

void fragment() {
	// UV 是单位六边形的局部 x/z 坐标。
	vec2 p = UV;
	float sdf = max(abs(p.y) - HALF_SQRT3, HALF_SQRT3 * abs(p.x) + 0.5 * abs(p.y) - HALF_SQRT3);
	float edge = smoothstep(-border_width, 0.0, sdf) * v_top;

	vec3 base = tile_color.rgb * mix(0.58, 1.0, v_top);
	ALBEDO = mix(base, border_color.rgb, edge);
	EMISSION = base * emissive * 0.45 + border_color.rgb * edge * emissive;
}