## 地图正交相机，绕父节点原点旋转并以光标为缩放锚点。
class_name MapCamera
extends Camera3D

@export_range(0.001, 0.02, 0.001) var orbit_speed: float = 0.005
@export_range(0.5, 0.95, 0.01) var zoom_factor: float = 0.8
@export_range(0.1, 1.0, 0.05) var minimum_zoom_ratio: float = 0.25

@onready var _initial_size := size
@onready var _initial_offset := Vector2(h_offset, v_offset)


func orbit_drag(horizontal_delta: float) -> void:
	var rotation_step := Basis(Vector3.UP, -horizontal_delta * orbit_speed)
	transform = Transform3D(rotation_step, Vector3.ZERO) * transform


func zoom_at(screen_position: Vector2) -> void:
	if projection != PROJECTION_ORTHOGONAL:
		return
	var anchor := project_ray_origin(screen_position)
	size = maxf(_initial_size * minimum_zoom_ratio, size * zoom_factor)
	var displacement := anchor - project_ray_origin(screen_position)
	var camera_basis := global_basis.orthonormalized()
	h_offset += displacement.dot(camera_basis.x)
	v_offset += displacement.dot(camera_basis.y)


func reset_zoom() -> void:
	size = _initial_size
	h_offset = _initial_offset.x
	v_offset = _initial_offset.y

func get_zoom_progress() -> float:
	var zoom_range := _initial_size * (1.0 - minimum_zoom_ratio)
	if zoom_range <= 0.0:
		return 0.0
	return clampf((_initial_size - size) / zoom_range, 0.0, 1.0)