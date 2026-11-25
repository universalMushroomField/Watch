// 通用分阶光照材质，将连续受光强度映射为离散亮度。
// 兼容旧资源路径。
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
/** 表面的基础着色，用于计算受光颜色和暗部补光。 */
uniform vec4 base_color : source_color = vec4(1.0);
/** 直接光照划分的亮度级数，值越小，阴影分界越明显。 */
uniform int shadow_steps : hint_range(2, 8, 1) = 3;
/** 暗部补光比例，提高后背光面更亮。 */
uniform float shadow_floor : hint_range(0.0, 1.0, 0.01) = 0.22;

// 设置基础颜色并添加暗部补光。
void fragment() {
	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * shadow_floor;
}

// 将当前光源的受光强度量化，再累加到漫反射光照。
void light() {
	float diffuse = max(dot(NORMAL, LIGHT), 0.0);
	float illumination = clamp(diffuse * ATTENUATION, 0.0, 1.0);
	float steps = float(shadow_steps);
	float band = min(floor(illumination * steps), steps - 1.0) / (steps - 1.0);
	DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * band * (1.0 - shadow_floor);
}
