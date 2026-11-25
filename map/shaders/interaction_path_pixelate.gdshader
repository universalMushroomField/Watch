// 交互路线的像素化通道，以屏幕方格中心判定路线覆盖范围。
// 兼容旧资源路径。
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
#include "res://map/shaders/path/interaction_path_pixelate.gdshaderinc"
