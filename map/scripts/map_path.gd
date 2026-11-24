class_name MapPath
extends MeshInstance3D

@export_range(0.005, 0.5, 0.005, "or_greater") var width: float = 0.05


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