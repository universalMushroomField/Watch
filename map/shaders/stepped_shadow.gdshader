// 通用分阶光照材质，将连续受光强度映射为离散亮度。
// 兼容旧资源路径。
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
#include "res://shaders/lighting/stepped_shadow.gdshaderinc"
