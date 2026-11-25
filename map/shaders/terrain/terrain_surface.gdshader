// 白模的主绘制通道，在视口边带内按流动噪声裁剪片元。
shader_type spatial;
render_mode cull_disabled, specular_disabled;
#include "res://map/shaders/terrain/terrain_surface.gdshaderinc"
