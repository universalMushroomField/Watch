// 地图粒子雾，使用实例数据控制深度、漂移相位、亮度和逐粒子像素着色。
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

/** 地表附近雾粒的颜色。 */
uniform vec4 surface_tint : source_color = vec4(0.94117647, 0.70980392, 0.54509804, 1.0);
/** 深层雾粒的颜色，按相对深度与地表颜色混合。 */
uniform vec4 mist_tint : source_color = vec4(0.65490196, 0.70588235, 0.92941176, 1.0);
/** 粒子面片在模型空间的基础尺寸，实例之间还会有大小差异。 */
uniform float particle_size : hint_range(0.1, 2.0) = 0.85;
/** 每个粒子横纵方向的采样格数，值越小，轮廓台阶越粗。 */
uniform int pixels_per_particle : hint_range(2, 24, 1) = 6;
/** 动画时间倍率，设为 0 可静止预览。 */
uniform float flow_speed : hint_range(0.0, 3.0) = 0.65;
/** 雾粒的不透明度倍率，设为 0 隐藏雾层。 */
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.62;
varying float depth;
varying float brightness;

// 按实例相位移动粒子中心，并在视空间展开朝向相机的面片。
void vertex() {
	depth = INSTANCE_CUSTOM.r;
	float phase = INSTANCE_CUSTOM.g * TAU;
	brightness = INSTANCE_CUSTOM.b;
	float t = TIME * flow_speed;
	float wave = t + INSTANCE_CUSTOM.a * TAU;
	vec3 drift = vec3(sin(wave), 0.4 * cos(wave + phase), cos(wave * 2.0 + phase));
	vec4 center = MODELVIEW_MATRIX * vec4(drift * mix(0.10, 0.85, depth), 1.0);
	float size = particle_size * mix(0.65, 1.45, brightness);
	center.xy += VERTEX.xy * size * length(MODEL_MATRIX[0].xyz);
	POSITION = PROJECTION_MATRIX * center;
}

// 在每个粒子的 UV 格心采样径向轮廓，按埋深混合颜色和透明度。
void fragment() {
	float resolution = float(max(2, pixels_per_particle));
	vec2 cell_uv = (min(floor(UV * resolution), vec2(resolution - 1.0)) + 0.5) / resolution;
	float radius = length(2.0 * cell_uv - 1.0);
	float mist = 1.0 - smoothstep(0.0, 1.0, radius);
	float core = 1.0 - smoothstep(0.04, 0.32, radius);
	ALBEDO = mix(surface_tint.rgb, mist_tint.rgb, depth) * mix(0.65, 1.3, brightness);
	ALPHA = fog_opacity * (0.65 * mist + 0.35 * core) * mix(1.0, 0.44, depth);
}
