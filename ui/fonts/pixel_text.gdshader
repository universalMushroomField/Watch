shader_type canvas_item;

uniform float coverage_threshold : hint_range(0.1, 0.9) = 0.45;
varying vec4 text_tint;

void vertex() {
	text_tint = COLOR;
}

void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	COLOR = vec4(text_tint.rgb * sample_color.rgb,
			text_tint.a * step(coverage_threshold, sample_color.a));
}
