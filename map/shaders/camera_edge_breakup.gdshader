// 旧版视口崩解入口，与地形主通道共享实现。
// 兼容旧资源路径。
shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://map/shaders/terrain/terrain_surface.gdshaderinc"
