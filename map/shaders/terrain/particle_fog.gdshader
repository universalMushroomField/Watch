shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 surface_tint : source_color = vec4(0.29, 0.66, 0.72, 1.0);
uniform vec4 mist_tint : source_color = vec4(0.22, 0.47, 0.65, 1.0);
uniform float particle_size : hint_range(0.1, 2.0) = 0.85;
uniform int pixels_per_particle : hint_range(2, 24, 1) = 6;
uniform float flow_speed : hint_range(0.0, 3.0) = 0.65;
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.62;
varying float depth;
varying float brightness;

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

void fragment() {
	float resolution = float(max(2, pixels_per_particle));
	vec2 cell_uv = (min(floor(UV * resolution), vec2(resolution - 1.0)) + 0.5) / resolution;
	float radius = length(2.0 * cell_uv - 1.0);
	float mist = 1.0 - smoothstep(0.0, 1.0, radius);
	float core = 1.0 - smoothstep(0.04, 0.32, radius);
	ALBEDO = mix(surface_tint.rgb, mist_tint.rgb, depth) * mix(0.65, 1.3, brightness);
	ALPHA = fog_opacity * (0.65 * mist + 0.35 * core) * mix(1.0, 0.44, depth);
}
