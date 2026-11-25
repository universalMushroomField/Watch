// 地形外扩轮廓通道，共享碎块位移与侵蚀判定。
// 兼容旧资源路径。
shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never, shadows_disabled;
#include "res://map/shaders/terrain/terrain_outline.gdshaderinc"
