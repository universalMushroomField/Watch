// 通用分阶光照材质。
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec4 base_color : source_color = vec4(1.0);

#include "res://public/shaders/lighting/palette_shadow.gdshaderinc"

void fragment() {
	ALBEDO = base_color.rgb;
	EMISSION = shadow_deep.rgb;
}

void light() {
	float illumination = clamp(dot(NORMAL, LIGHT) * ATTENUATION, 0.0, 1.0);
	vec3 lit = ALBEDO * LIGHT_COLOR / PI;
	DIFFUSE_LIGHT += max(palette_shadow_ramp(illumination, lit) - shadow_deep.rgb, vec3(0.0));
}
