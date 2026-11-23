## 在三维地形上绘制六边形蜂巢地图。
##
## 六边形不生成实体格子，而是把蜂巢边界投影到地形上：每条边是一堵没有厚度
## 的竖直墙，顶边沿着平滑后的地表高度，底边埋进地形。格子内部保留原始地形，
## 地图仍然是一整片地面，只是被六边形墙分割成一个个地点。
##
## 高度：先把地形 mesh 的顶点烘成 0.5m 的高度场，取邻域最大值保证不低于
## 地表，再做两次盒式模糊；墙顶取模糊后的高度再加上 [member MapConfig.hex_lift]，
## 因此既高于地表，又不会沿地形台阶出现锯齿。
class_name MapHexLayer
extends Node3D

const WALL_SHADER: Shader = preload("res://map/shaders/hex_wall.gdshader")
const SQRT3 := 1.7320508075688772
## 高度场的采样间距（世界单位）。
const FIELD_CELL := 0.5
## 邻域最大值滤波的半径（格）。
const FIELD_RADIUS := 1
## 高度场模糊次数。
const FIELD_BLUR_PASSES := 2
## 六边形脚印采样的半径比例。
const FOOTPRINT_RATIO := 0.62
## 每条六边形边沿分成几段，用来贴合地形起伏。
const WALL_SEGMENTS := 4
## 墙底埋进地形的深度。
const WALL_SINK := 0.5
## 墙至少保留的高度，避免贴地时完全看不见。
const WALL_MIN_HEIGHT := 0.35
## 墙在法线方向的最小厚度：完全零厚度的竖直面在正对视线时会消失。
const WALL_THICKNESS := 0.12

const TYPE_COLORS := {
	MapNode.Type.START: Color(0.30, 0.72, 0.42),
	MapNode.Type.BATTLE: Color(0.36, 0.55, 0.82),
	MapNode.Type.ELITE: Color(0.62, 0.36, 0.82),
	MapNode.Type.EVENT: Color(0.30, 0.68, 0.70),
	MapNode.Type.TREASURE: Color(0.85, 0.66, 0.25),
	MapNode.Type.SHOP: Color(0.85, 0.50, 0.30),
	MapNode.Type.REST: Color(0.80, 0.36, 0.44),
	MapNode.Type.BOSS: Color(0.82, 0.22, 0.22),
}

const WALL_COLOR := Color(0.24, 0.30, 0.40)
const WALL_TOP := Color(0.55, 0.64, 0.76)
const WALL_REACHABLE := Color(0.95, 0.72, 0.28)
const WALL_CURRENT := Color(0.28, 0.86, 0.98)
const WALL_VISITED := Color(0.22, 0.25, 0.30)

## 地形网格，用来读取地表高度。
@export var terrain: MeshInstance3D
## 相机，用来计算可视范围。
@export var camera: Camera3D
## 六边形节点的父节点，留空时自动创建。
@export var tiles_root: Node3D
## 高度场最大值滤波半径。
@export var sample_radius_cells: int = FIELD_RADIUS
## 高度场模糊次数。
@export var height_smoothing_passes: int = FIELD_BLUR_PASSES
## 六边形基座高度的邻接平滑次数。
@export var neighbor_smoothing_passes: int = 3

var run: MapRun
var layout: HexLayout

var _tiles := {}
var _walls: Array[Dictionary] = []
var _hover_id := -1
var _base_heights := {}

var _label_font: SystemFont
var _wall_root: Node3D

var _field := PackedFloat32Array()
var _raw_field := PackedFloat32Array()
var _field_columns := 0
var _field_rows := 0
var _field_origin := Vector2.ZERO
var _field_ready := false
var _board_offset := Vector2.ZERO
var _board_angle := 0.0


func _ready() -> void:
	if terrain == null:
		terrain = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if tiles_root == null:
		tiles_root = Node3D.new()
		tiles_root.name = "Tiles"
		add_child(tiles_root)
	_ensure_wall_root()
	_label_font = SystemFont.new()
	_label_font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Noto Sans CJK SC",
		"sans-serif",
	])
	_build_height_field()


## 根据地形和相机可视范围计算棋盘布局。
func make_layout(config: MapConfig) -> HexLayout:
	_build_height_field()
	var rect := _available_rect(config)
	var target_radius := maxf(config.hex_radius, 0.5)
	var interior_columns := int(floor(rect.size.x / (SQRT3 * target_radius) - 2.5))
	var interior_rows := int(floor((rect.size.y / target_radius - 0.5) / 1.5))
	interior_columns = clampi(interior_columns, 2, maxi(config.max_columns, 2))
	interior_rows = clampi(interior_rows, 2, maxi(config.max_rows, 2))

	# 用实际列数重新拟合半径，保证棋盘完整落在可用矩形内。
	var span_columns := SQRT3 * (float(interior_columns) + 2.5)
	var span_rows := 1.5 * float(interior_rows) + 0.5
	var radius := minf(rect.size.x / span_columns, rect.size.y / span_rows)
	radius = minf(radius, target_radius)
	return HexLayout.new(interior_columns, interior_rows, radius)


## 显示一张地图；[param map_run] 的 [member MapRun.layout] 必须已经确定。
func show_run(map_run: MapRun) -> void:
	run = map_run
	if run != null and run.layout != null:
		layout = run.layout
	else:
		layout = HexLayout.new()
	_build_height_field()
	_clear_tiles()
	if run == null:
		return
	_board_angle = _camera_board_angle()
	_compute_board_offset(_available_rect(run.config))
	_compute_base_heights()
	_create_tiles()
	_create_walls()
	refresh()


## 按当前进度刷新墙的颜色、标签和可达状态。
func refresh() -> void:
	if run == null or run.graph == null:
		return
	var reachable := {}
	for node in run.get_reachable_nodes():
		reachable[node.id] = true

	for node in run.graph.nodes:
		var entry: Dictionary = _tiles.get(node.id, {})
		if entry.is_empty():
			continue
		var type_color: Color = TYPE_COLORS.get(node.type, Color(0.5, 0.5, 0.5))
		var label_color := type_color.lightened(0.55)
		if node.visited and node.id != run.current_id:
			label_color = Color(0.62, 0.65, 0.70)
		elif not reachable.has(node.id):
			label_color = type_color.lightened(0.05)

		if node.id == run.current_id:
			label_color = Color(1.0, 1.0, 1.0)
		elif node.id == _hover_id:
			label_color = Color(1.0, 0.95, 0.72)

		var label: Label3D = entry["label"]
		label.text = node.get_short_label()
		label.modulate = label_color
		label.scale = Vector3.ONE * (1.22 if node.id == run.current_id else 1.0)

		var holder: Node3D = entry["holder"]
		var lift := 0.22 if node.id == _hover_id else 0.0
		holder.position.y = float(entry["base_y"]) + lift

	for wall in _walls:
		var material: ShaderMaterial = wall["material"]
		var ids: Array = wall["ids"]
		var is_current := false
		var is_reachable := false
		var all_visited := true
		for id in ids:
			var node := run.graph.get_node_by_id(int(id))
			if node == null:
				continue
			if node.id == run.current_id:
				is_current = true
			if reachable.has(node.id):
				is_reachable = true
			if not node.visited:
				all_visited = false
		if bool(ids.has(_hover_id)):
			is_current = true

		var wall_color := WALL_COLOR
		var top_color := WALL_TOP
		var emissive := 0.0
		if is_current:
			wall_color = WALL_CURRENT
			top_color = WALL_CURRENT.lightened(0.55)
			emissive = 0.75
		elif is_reachable:
			wall_color = WALL_REACHABLE
			top_color = WALL_REACHABLE.lightened(0.45)
			emissive = 0.45
		elif all_visited:
			wall_color = WALL_VISITED
			top_color = WALL_VISITED.lightened(0.18)

		material.set_shader_parameter("wall_color", wall_color)
		material.set_shader_parameter("top_color", top_color)
		material.set_shader_parameter("emissive", emissive)


## 设置鼠标悬停的节点编号，-1 表示没有。
func set_hover_id(node_id: int) -> void:
	if _hover_id == node_id:
		return
	_hover_id = node_id
	refresh()


## 当前悬停的节点编号。
func get_hover_id() -> int:
	return _hover_id


## 已经生成的六边形数量。
func get_tile_count() -> int:
	return _tiles.size()


## 已经生成的墙数量。
func get_wall_count() -> int:
	return _walls.size()


## 返回屏幕坐标（SubViewport 像素）下的地点，没有命中时返回 null。
func node_at_screen(screen_position: Vector2) -> MapNode:
	if run == null or run.graph == null or camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	if absf(direction.y) < 0.0001:
		return null

	var best: MapNode = null
	var best_distance := INF
	for node in run.graph.nodes:
		var entry: Dictionary = _tiles.get(node.id, {})
		if entry.is_empty():
			continue
		var top_y := float(entry["base_y"])
		var distance := (top_y - origin.y) / direction.y
		if distance <= 0.0:
			continue
		var hit := origin + direction * distance
		var holder: Node3D = entry["holder"]
		var dx := hit.x - holder.position.x
		var dz := hit.z - holder.position.z
		var local := _rotate(Vector2(dx, dz), -_board_angle)
		if not _in_hex(local.x, local.y, layout.hex_radius):
			continue
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## 把地形顶点烘成高度场，并保留一份未平滑的原始值用于墙底。
func _build_height_field() -> void:
	if terrain == null or terrain.mesh == null:
		return
	var mesh := terrain.mesh
	var box: AABB = terrain.global_transform * mesh.get_aabb()
	_field_origin = Vector2(box.position.x, box.position.z)
	_field_columns = ceili(box.size.x / FIELD_CELL) + 1
	_field_rows = ceili(box.size.z / FIELD_CELL) + 1
	_field.resize(_field_columns * _field_rows)
	_field.fill(-1e20)

	var transform := terrain.global_transform
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var world := transform * vertex
			var column := clampi(int(floor((world.x - _field_origin.x) / FIELD_CELL)), 0, _field_columns - 1)
			var row := clampi(int(floor((world.z - _field_origin.y) / FIELD_CELL)), 0, _field_rows - 1)
			var index := row * _field_columns + column
			if world.y > _field[index]:
				_field[index] = world.y

	var fallback := box.position.y
	for index in range(_field.size()):
		if _field[index] <= -1e19:
			_field[index] = fallback

	_raw_field = _field.duplicate()
	_field = _box_max(_field, _field_columns, _field_rows, sample_radius_cells)
	_field = _box_blur(_field, _field_columns, _field_rows, sample_radius_cells, height_smoothing_passes)
	_field_ready = true


## 地形和相机共同决定、棋盘可以占用的矩形（世界 XZ）。
func _available_rect(config: MapConfig) -> Rect2:
	var rect := Rect2(-12.0, -12.0, 24.0, 24.0)
	if terrain != null and terrain.mesh != null:
		var box: AABB = terrain.global_transform * terrain.mesh.get_aabb()
		rect = Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
	rect = rect.grow(-maxf(config.board_margin, 0.0))

	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		var viewport := get_viewport()
		var viewport_size := Vector2(1152.0, 648.0)
		if viewport != null and viewport.size.x > 0 and viewport.size.y > 0:
			viewport_size = Vector2(viewport.size)
		var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
		var half_width := camera.size * aspect * 0.5
		var forward := -camera.global_basis.z
		var elevation := asin(clampf(absf(forward.y), 0.0, 1.0))
		var half_depth := camera.size * 0.5 / maxf(sin(elevation), 0.2)
		var center := _camera_ground_center()
		var view_rect := Rect2(
			center.x - half_width,
			center.y - half_depth,
			half_width * 2.0,
			half_depth * 2.0,
		)
		var clipped := rect.intersection(view_rect)
		if clipped.size.x > 0.0 and clipped.size.y > 0.0:
			rect = clipped
	return rect


## 相机视线与 y=0 平面的交点，返回 XZ。
func _camera_ground_center() -> Vector2:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	if absf(forward.y) < 0.001:
		return Vector2(origin.x, origin.z)
	var distance := -origin.y / forward.y
	if distance <= 0.0:
		return Vector2(origin.x, origin.z)
	var point := origin + forward * distance
	return Vector2(point.x, point.z)


## 把棋盘整体平移到可用矩形的中心。
func _compute_board_offset(rect: Rect2) -> void:
	if run == null or run.graph == null or run.graph.nodes.is_empty():
		return
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for node in run.graph.nodes:
		var center := _raw_hex_center(node)
		for index in range(6):
			var corner := _hex_corner(center, index)
			min_x = minf(min_x, corner.x)
			max_x = maxf(max_x, corner.x)
			min_z = minf(min_z, corner.y)
			max_z = maxf(max_z, corner.y)
	if min_x > max_x or min_z > max_z:
		return
	var board_center := Vector2((min_x + max_x) * 0.5, (min_z + max_z) * 0.5)
	_board_offset = rect.get_center() - board_center


## 每个六边形的平滑基座高度：脚印最高点，再做邻接平均，最后保证不低于原始最高点。
func _compute_base_heights() -> void:
	_base_heights.clear()
	var raw := {}
	for node in run.graph.nodes:
		var center := _hex_center(node)
		raw[node.id] = _footprint_max(center.x, center.y)

	var smooth := raw.duplicate()
	for iteration in range(maxi(neighbor_smoothing_passes, 0)):
		var next := {}
		for node in run.graph.nodes:
			var sum := float(smooth[node.id])
			var count := 1
			for neighbor_id in node.neighbor_ids:
				if smooth.has(neighbor_id):
					sum += float(smooth[neighbor_id])
					count += 1
			next[node.id] = sum / float(count)
		smooth = next

	for node in run.graph.nodes:
		var base := maxf(float(smooth[node.id]), float(raw[node.id]))
		_base_heights[node.id] = base + run.config.hex_lift


## 六边形脚印内的地表最高点。
func _footprint_max(center_x: float, center_z: float) -> float:
	var height := _sample_height(center_x, center_z)
	var radius := layout.hex_radius * FOOTPRINT_RATIO
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var sample_x := center_x + cos(angle) * radius
		var sample_z := center_z + sin(angle) * radius
		height = maxf(height, _sample_height(sample_x, sample_z))
	return height


## 采样平滑后的高度（墙顶使用）。
func _sample_height(x: float, z: float) -> float:
	return _sample_field(_field, x, z)


## 采样未平滑的地表高度（墙底使用）。
func _sample_raw(x: float, z: float) -> float:
	return _sample_field(_raw_field, x, z)


## 双线性采样高度场。
func _sample_field(values: PackedFloat32Array, x: float, z: float) -> float:
	if not _field_ready or _field_columns <= 0 or _field_rows <= 0:
		return 0.0
	var fx := clampf((x - _field_origin.x) / FIELD_CELL, 0.0, float(_field_columns - 1))
	var fz := clampf((z - _field_origin.y) / FIELD_CELL, 0.0, float(_field_rows - 1))
	var x0 := int(floor(fx))
	var z0 := int(floor(fz))
	var x1 := mini(x0 + 1, _field_columns - 1)
	var z1 := mini(z0 + 1, _field_rows - 1)
	var tx := fx - float(x0)
	var tz := fz - float(z0)
	var v00 := values[z0 * _field_columns + x0]
	var v10 := values[z0 * _field_columns + x1]
	var v01 := values[z1 * _field_columns + x0]
	var v11 := values[z1 * _field_columns + x1]
	var top := lerpf(v00, v10, tx)
	var bottom := lerpf(v01, v11, tx)
	return lerpf(top, bottom, tz)


## 未加棋盘偏移的六边形中心，列方向对齐相机屏幕的左右方向。
func _raw_hex_center(node: MapNode) -> Vector2:
	var local := Vector2(
		(float(node.column) + 0.5 * float(node.row & 1)) * layout.get_column_step(),
		float(node.row) * layout.get_row_step(),
	)
	return _rotate(local, _board_angle)


## 加上棋盘偏移后的六边形中心。
func _hex_center(node: MapNode) -> Vector2:
	return _raw_hex_center(node) + _board_offset


## 尖顶六边形的第 [param index] 个角。
func _hex_corner(center: Vector2, index: int) -> Vector2:
	var angle := _board_angle + PI / 6.0 + TAU * float(index % 6) / 6.0
	return center + Vector2(cos(angle), sin(angle)) * layout.hex_radius


## 绕原点旋转 XZ 平面上的点。
func _rotate(value: Vector2, angle: float) -> Vector2:
	var cosine := cos(angle)
	var sine := sin(angle)
	return Vector2(value.x * cosine - value.y * sine, value.x * sine + value.y * cosine)


## 让棋盘列方向与相机屏幕的左右方向一致，起点在左、Boss 在右。
func _camera_board_angle() -> float:
	if camera == null:
		return 0.0
	var right := camera.global_basis.x
	return atan2(right.z, right.x)


## 尖顶六边形的点内测试。
func _in_hex(dx: float, dz: float, radius: float) -> bool:
	var half := SQRT3 * 0.5 * radius
	var ax := absf(dx)
	var az := absf(dz)
	return ax <= half + 0.0001 and 0.5 * ax + SQRT3 * 0.5 * az <= half + 0.0001


## 用六边形边的中点作为唯一键，相邻两格共享同一条边。
func _edge_key(a: Vector2, b: Vector2) -> Vector2i:
	var mid := (a + b) * 0.5
	return Vector2i(roundi(mid.x * 100.0), roundi(mid.y * 100.0))


func _create_tiles() -> void:
	_tiles.clear()
	if run == null or run.graph == null:
		return
	for node in run.graph.nodes:
		var entry := {}
		var center := _hex_center(node)
		var base_y: float = _base_heights.get(node.id, 0.0)

		var holder := Node3D.new()
		holder.name = "Hex_%d" % node.id
		holder.position = Vector3(center.x, base_y, center.y)
		tiles_root.add_child(holder)

		var label := Label3D.new()
		label.name = "Label"
		label.font = _label_font
		label.font_size = 56
		label.pixel_size = 0.02
		label.outline_size = 14
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		label.modulate = Color.WHITE
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0.0, 0.62, 0.0)
		label.text = node.get_short_label()
		holder.add_child(label)

		entry["holder"] = holder
		entry["label"] = label
		entry["base_y"] = base_y
		_tiles[node.id] = entry


## 沿蜂巢边界生成没有厚度的墙。
func _create_walls() -> void:
	_walls.clear()
	if run == null or run.graph == null or _wall_root == null:
		return

	var edges := {}
	for node in run.graph.nodes:
		var center := _hex_center(node)
		for index in range(6):
			var a := _hex_corner(center, index)
			var b := _hex_corner(center, index + 1)
			var key := _edge_key(a, b)
			if not edges.has(key):
				edges[key] = {"a": a, "b": b, "ids": [] as Array[int]}
			var ids: Array = edges[key]["ids"]
			if not ids.has(node.id):
				ids.append(node.id)

	for key in edges:
		var edge: Dictionary = edges[key]
		_create_wall(edge["a"], edge["b"], edge["ids"])


func _create_wall(a: Vector2, b: Vector2, ids: Array) -> void:
	var top_points: Array[Vector3] = []
	var bottom_points: Array[Vector3] = []
	var lift := run.config.hex_lift
	for segment in range(WALL_SEGMENTS + 1):
		var t := float(segment) / float(WALL_SEGMENTS)
		var point := a.lerp(b, t)
		var top := maxf(_sample_height(point.x, point.y), _sample_raw(point.x, point.y)) + lift
		var bottom := minf(_sample_raw(point.x, point.y) - WALL_SINK, top - WALL_MIN_HEIGHT)
		top_points.append(Vector3(point.x, top, point.y))
		bottom_points.append(Vector3(point.x, bottom, point.y))

	var normal := Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
	if normal.length_squared() < 0.0001:
		normal = Vector3.RIGHT
	var half := WALL_THICKNESS * 0.5
	var front_offset := normal * half
	var back_offset := -front_offset
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(WALL_SEGMENTS):
		var t0 := float(segment) / float(WALL_SEGMENTS)
		var t1 := float(segment + 1) / float(WALL_SEGMENTS)
		var top_a := top_points[segment]
		var top_b := top_points[segment + 1]
		var bottom_a := bottom_points[segment]
		var bottom_b := bottom_points[segment + 1]

		var front_top_a := top_a + front_offset
		var front_top_b := top_b + front_offset
		var front_bottom_a := bottom_a + front_offset
		var front_bottom_b := bottom_b + front_offset
		var back_top_a := top_a + back_offset
		var back_top_b := top_b + back_offset
		var back_bottom_a := bottom_a + back_offset
		var back_bottom_b := bottom_b + back_offset

		# 朝向相机的一面
		_add_vertex(surface, front_top_a, normal, Vector2(t0, 1.0))
		_add_vertex(surface, front_bottom_a, normal, Vector2(t0, 0.0))
		_add_vertex(surface, front_bottom_b, normal, Vector2(t1, 0.0))
		_add_vertex(surface, front_top_a, normal, Vector2(t0, 1.0))
		_add_vertex(surface, front_bottom_b, normal, Vector2(t1, 0.0))
		_add_vertex(surface, front_top_b, normal, Vector2(t1, 1.0))

		# 背面，保证从任何方向看都有可见面
		_add_vertex(surface, back_top_b, -normal, Vector2(t1, 1.0))
		_add_vertex(surface, back_bottom_b, -normal, Vector2(t1, 0.0))
		_add_vertex(surface, back_bottom_a, -normal, Vector2(t0, 0.0))
		_add_vertex(surface, back_top_b, -normal, Vector2(t1, 1.0))
		_add_vertex(surface, back_bottom_a, -normal, Vector2(t0, 0.0))
		_add_vertex(surface, back_top_a, -normal, Vector2(t0, 1.0))

		# 墙顶盖，让墙的正上方也有一条清晰的边
		_add_vertex(surface, front_top_a, Vector3.UP, Vector2(0.0, 1.0))
		_add_vertex(surface, front_top_b, Vector3.UP, Vector2(1.0, 1.0))
		_add_vertex(surface, back_top_b, Vector3.UP, Vector2(1.0, 1.0))
		_add_vertex(surface, front_top_a, Vector3.UP, Vector2(0.0, 1.0))
		_add_vertex(surface, back_top_b, Vector3.UP, Vector2(1.0, 1.0))
		_add_vertex(surface, back_top_a, Vector3.UP, Vector2(0.0, 1.0))

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Wall"
	mesh_instance.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = WALL_SHADER
	material.set_shader_parameter("wall_color", WALL_COLOR)
	material.set_shader_parameter("top_color", WALL_TOP)
	material.set_shader_parameter("emissive", 0.0)
	mesh_instance.material_override = material
	_wall_root.add_child(mesh_instance)
	_walls.append({
		"mesh": mesh_instance,
		"material": material,
		"ids": ids,
	})


func _clear_tiles() -> void:
	for node_id in _tiles.keys():
		var entry: Dictionary = _tiles[node_id]
		var holder: Node3D = entry.get("holder")
		if is_instance_valid(holder):
			holder.free()
	_tiles.clear()
	if _wall_root != null:
		for child in _wall_root.get_children():
			child.free()
	_walls.clear()


func _ensure_wall_root() -> void:
	if _wall_root != null:
		return
	_wall_root = Node3D.new()
	_wall_root.name = "Walls"
	tiles_root.add_child(_wall_root)


## 每个格取邻域最大值。
func _box_max(values: PackedFloat32Array, columns: int, rows: int, radius: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(values.size())
	for row in range(rows):
		for column in range(columns):
			var best := -1e20
			for offset_row in range(-radius, radius + 1):
				var sample_row := clampi(row + offset_row, 0, rows - 1)
				for offset_column in range(-radius, radius + 1):
					var sample_column := clampi(column + offset_column, 0, columns - 1)
					best = maxf(best, values[sample_row * columns + sample_column])
			result[row * columns + column] = best
	return result


## 盒式模糊，纯平均，不保留局部最大值。
func _box_blur(
		values: PackedFloat32Array,
		columns: int,
		rows: int,
		radius: int,
		passes: int,
) -> PackedFloat32Array:
	var current := values
	for iteration in range(maxi(passes, 0)):
		var next := PackedFloat32Array()
		next.resize(values.size())
		for row in range(rows):
			for column in range(columns):
				var sum := 0.0
				var count := 0
				for offset_row in range(-radius, radius + 1):
					var sample_row := clampi(row + offset_row, 0, rows - 1)
					for offset_column in range(-radius, radius + 1):
						var sample_column := clampi(column + offset_column, 0, columns - 1)
						sum += current[sample_row * columns + sample_column]
						count += 1
				next[row * columns + column] = sum / float(count)
		current = next
	return current


func _add_vertex(surface: SurfaceTool, vertex: Vector3, normal: Vector3, uv: Vector2) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(vertex)