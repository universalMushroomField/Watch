## 地图正交相机，绕屏幕中心旋转并以光标为缩放锚点。
class_name MapCamera
extends Camera3D

@export_range(0.001, 0.02, 0.001) var orbit_speed: float = 0.005
## 单次鼠标移动中，每个轴独立需要超过的像素距离。
@export_range(0.0, 16.0, 0.5, "suffix:px") var orbit_deadzone: float = 2.0
@export_range(1.0, 89.0, 1.0, "degrees") var min_pitch_degrees: float = 20.0
@export_range(1.0, 89.0, 1.0, "degrees") var max_pitch_degrees: float = 85.0
@export_range(0.5, 0.95, 0.01) var zoom_factor: float = 0.8
@export_range(0.1, 1.0, 0.05) var minimum_zoom_ratio: float = 0.25

@onready var _initial_size := size
@onready var _initial_offset := Vector2(h_offset, v_offset)


func orbit_drag(horizontal_delta: float, vertical_delta: float = 0.0) -> void:
	var horizontal := _axis_delta(horizontal_delta)
	var vertical := _axis_delta(vertical_delta)
	if is_zero_approx(horizontal) and is_zero_approx(vertical):
		return
	var yaw := Basis(Vector3.UP, -horizontal * orbit_speed)
	var rotation_step := yaw
	if not is_zero_approx(vertical):
		var elevation := asin(clampf(transform.basis.z.normalized().y, -1.0, 1.0))
		var lower := deg_to_rad(minf(min_pitch_degrees, max_pitch_degrees))
		var upper := deg_to_rad(maxf(min_pitch_degrees, max_pitch_degrees))
		var next_elevation := clampf(elevation - vertical * orbit_speed, lower, upper)
		var right := (yaw * transform.basis.x).normalized()
		rotation_step = Basis(right, elevation - next_elevation) * yaw
	var viewport_rect := get_viewport().get_visible_rect()
	var screen_center := viewport_rect.get_center()
	var ray_origin := project_ray_origin(screen_center)
	var ray_direction := project_ray_normal(screen_center)
	var parent := get_parent_node_3d()
	var parent_transform := parent.global_transform if parent != null else Transform3D.IDENTITY
	var ground := Plane(parent_transform.basis.y.normalized(), parent_transform.origin)
	var hit: Variant = ground.intersects_ray(ray_origin, ray_direction)
	if hit == null:
		return
	var pivot: Vector3 = parent_transform.affine_inverse() * hit
	transform = Transform3D(rotation_step, pivot - rotation_step * pivot) * transform


func _axis_delta(delta: float) -> float:
	return signf(delta) * maxf(0.0, absf(delta) - orbit_deadzone)


func zoom_at(screen_position: Vector2) -> void:
	if projection != PROJECTION_ORTHOGONAL:
		return
	var anchor := project_ray_origin(screen_position)
	size = maxf(_initial_size * minimum_zoom_ratio, size * zoom_factor)
	_shift_view(anchor - project_ray_origin(screen_position))


func is_zoomed() -> bool:
	return projection == PROJECTION_ORTHOGONAL and size < _initial_size and not is_equal_approx(size, _initial_size)


func pan_drag(screen_delta: Vector2) -> void:
	if not is_zoomed():
		return
	_shift_view(project_ray_origin(Vector2.ZERO) - project_ray_origin(screen_delta))


func _shift_view(displacement: Vector3) -> void:
	var camera_basis := global_basis.orthonormalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var diagonal := project_ray_origin(viewport_size) - project_ray_origin(Vector2.ZERO)
	var zoom_margin := maxf(0.0, _initial_size / size - 1.0) * 0.5
	var limit_x := absf(diagonal.dot(camera_basis.x)) * zoom_margin
	var limit_y := absf(diagonal.dot(camera_basis.y)) * zoom_margin
	h_offset = clampf(h_offset + displacement.dot(camera_basis.x), _initial_offset.x - limit_x, _initial_offset.x + limit_x)
	v_offset = clampf(v_offset + displacement.dot(camera_basis.y), _initial_offset.y - limit_y, _initial_offset.y + limit_y)

func reset_zoom(map_center: Vector3) -> void:
	size = _initial_size
	h_offset = _initial_offset.x
	v_offset = _initial_offset.y
	var screen_center := get_viewport().get_visible_rect().get_center()
	var displacement := map_center - project_ray_origin(screen_center)
	var depth := global_basis.z.normalized()
	global_position += displacement - depth * displacement.dot(depth)


func get_zoom_progress() -> float:
	var zoom_range := _initial_size * (1.0 - minimum_zoom_ratio)
	if zoom_range <= 0.0:
		return 0.0
	return clampf((_initial_size - size) / zoom_range, 0.0, 1.0)
