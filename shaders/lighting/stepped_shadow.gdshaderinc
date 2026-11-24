uniform vec4 base_color : source_color = vec4(1.0);
uniform int shadow_steps : hint_range(2, 8, 1) = 3;
uniform float shadow_floor : hint_range(0.0, 1.0, 0.01) = 0.22;

void fragment() {
	ALBEDO = base_color.rgb;
	EMISSION = base_color.rgb * shadow_floor;
}

void light() {
	float diffuse = max(dot(NORMAL, LIGHT), 0.0);
	float illumination = clamp(diffuse * ATTENUATION, 0.0, 1.0);
	float steps = float(shadow_steps);
	float band = min(floor(illumination * steps), steps - 1.0) / (steps - 1.0);
	DIFFUSE_LIGHT += ALBEDO * (LIGHT_COLOR / PI) * band * (1.0 - shadow_floor);
}