class_name MapPath
extends MeshInstance3D

@export_range(0.005, 0.5, 0.005, "or_greater") var width: float = 0.05
## 线色在色板里的下标；-1 表示用 [constant ArtPalette.PATH_LINE]。
@export var palette_index: int = -1
## 线的不透明度；负数表示用 [constant ArtPalette.PATH_LINE_ALPHA]。
@export var line_alpha: float = -1.0


## 折线颜色取自色板，模板里的 `pixel_color` 只作编辑器预览。
func _ready() -> void:
	var material := material_override as ShaderMaterial
	if material == null:
		return
	var index := palette_index if palette_index >= 0 else ArtPalette.PATH_LINE
	var opacity := line_alpha if line_alpha >= 0.0 else ArtPalette.PATH_LINE_ALPHA
	var line := ArtPalette.color(index)
	line.a = opacity
	material.set_shader_parameter("pixel_color", line)


func add_segment(surface: SurfaceTool, a: Vector3, b: Vector3, view_depth: Vector3,
		width_scale: float, end_alpha: float = 1.0) -> void:
	var perpendicular := (b - a).cross(view_depth)
	if perpendicular.length_squared() < 0.00000001:
		return
	var offset := perpendicular.normalized() * width * width_scale * 0.5
	var corners := [a - offset, a + offset, b - offset, b + offset]
	for index in [0, 1, 2, 1, 3, 2]:
		surface.set_color(Color(1.0, 1.0, 1.0, end_alpha if index >= 2 else 1.0))
		surface.set_uv(Vector2((1.0 if index >= 2 else 0.0), float(index % 2)))
		surface.set_normal((global_basis.inverse() * perpendicular).normalized())
		surface.add_vertex(to_local(corners[index]))
