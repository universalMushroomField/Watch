// Shared cool shadow ramp. Defaults match the dark blue row in color_palette_art.tres.
uniform vec4 shadow_deep : source_color = vec4(0.015686, 0.0, 0.145098, 1.0);
uniform vec4 shadow_middle : source_color = vec4(0.0, 0.015686, 0.305882, 1.0);
uniform vec4 shadow_edge : source_color = vec4(0.105882, 0.211765, 0.529412, 1.0);
uniform int shadow_steps : hint_range(5, 8, 1) = 6;

vec3 palette_shadow_ramp(float illumination, vec3 lit_color) {
	float steps = float(shadow_steps);
	float band = min(floor(illumination * steps), steps - 1.0);
	if (band < 1.0) {
		return shadow_deep.rgb;
	}
	if (band < 2.0) {
		return shadow_middle.rgb;
	}
	if (band < 3.0) {
		return shadow_edge.rgb;
	}
	float amount = (band - 2.0) / (steps - 3.0);
	return mix(shadow_edge.rgb, lit_color, amount);
}
