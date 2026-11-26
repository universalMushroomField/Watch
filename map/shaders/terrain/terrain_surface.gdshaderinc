#include "res://shaders/include/viewport_edge_noise.gdshaderinc"

bool side_cell_missing(vec2 uv, vec2 viewport_size, float time) {
    float distance_x = min(uv.x, 1.0 - uv.x);
    if (distance_x >= breakup_width || breakup_strength <= 0.0) {
        return false;
    }
    vec2 cell = floor(uv * viewport_size / fragment_pixels);
    float noise = value_noise(cell + vec2(time * flow_speed, 0.0));
    return noise < breakup_strength * (1.0 - smoothstep(0.0, breakup_width, distance_x));
}
