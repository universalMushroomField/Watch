## 在三维地形上绘制六边形蜂巢地图。
##
## 高度：先把地形 mesh 的顶点烘成 0.5m 的高度场，取邻域最大值保证不低于
## 地表，再做两次盒式模糊；每个六边形按自身脚印采样后，再做一次邻接平滑，
## 最后整体抬升 [member MapConfig.hex_lift]。这样棋盘既高于地表，又不会出现
## 一格一格跳动的锯齿。
class_name MapHexLayer
extends Node3D

const HEX_SHADER: Shader = preload("res://map/shaders/hex_tile.gdshader")
const SQRT3 := 1.7320508075688772
## 高度场的采样间距（世界单位）。
const FIELD_CELL := 0.5
## 邻域最大值滤波的半径（格）。
const FIELD_RADIUS := 2
## 高度场模糊次数。
const FIELD_BLUR_PASSES := 2
## 六边形脚印采样的半径比例。
const FOOTPRINT_RATIO := 0.62

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
var _hover_id := -1
var _base_heights := {}

var _unit_mesh: ArrayMesh
var _label_font: SystemFont

var _field := PackedFloat32Array()
var _field_columns := 0
var _field_rows := 0
var _field_origin := Vector2.ZERO
var _field_ready := false
var _board_offset := Vector2.ZERO


func _ready() -> void:
	if terrain == null:
		terrain = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if tiles_root == null:
		tiles_root = Node3D.new()
		tiles_root.name = "Tiles"
		add_child(tiles_root)
	_label_font = SystemFont.new()
	_label_font.font_names = PackedStringArray([
		"Microsoft YaHei UI",
		"Microsoft YaHei",
		"Noto Sans CJK SC",
		"sans-serif",
	])
	_unit_mesh = _build_unit_hex()
	_build_height_field()


## 根据地形和相机可视范围计算棋盘布局。
func make_layout(config: MapConfig) -> HexLayout:
	_build_height_field()
	var rect := _available_rect(config)
	var target_radius := maxf(config.hex_radius, 0.5)
	var interior_columns := int(floor(rect.size.x / (1.5 * target_radius) - 3.5 / 1.5))
	var interior_rows := int(floor(rect.size.y / (SQRT3 * target_radius) - 0.5))
	interior_columns = clampi(interior_columns, 2, maxi(config.max_columns, 2))
	interior_rows = clampi(interior_rows, 2, maxi(config.max_rows, 2))

	# 用实际列数重新拟合半径，保证棋盘完整落在可用矩形内。
	var span_columns := 1.5 * float(interior_columns) + 3.5
	var span_rows := SQRT3 * (float(interior_rows) + 0.5)
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
	_compute_board_offset(_available_rect(run.config))
	_compute_base_heights()
	_create_tiles()
	refresh()


## 按当前进度刷新颜色、标签和可达状态。
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
		var color: Color = TYPE_COLORS.get(node.type, Color(0.5, 0.5, 0.5))
		var border := color.lightened(0.45)
		var label_color := Color(1.0, 1.0, 1.0)
		var emissive := 0.0

		if node.visited and node.id != run.current_id:
			color = color.darkened(0.62)
			border = border.darkened(0.45)
			label_color = Color(0.72, 0.72, 0.72)
		elif not reachable.has(node.id):
			color = color.darkened(0.22)

		if node.id == run.current_id:
			border = Color(1.0, 1.0, 1.0)
			emissive = 0.55
			label_color = Color(1.0, 1.0, 1.0)
		elif reachable.has(node.id):
			border = Color(1.0, 0.84, 0.36)
			emissive = 0.40

		if node.id == _hover_id:
			color = color.lightened(0.18)
			emissive = maxf(emissive, 0.55)

		var material: ShaderMaterial = entry["material"]
		material.set_shader_parameter("tile_color", color)
		material.set_shader_parameter("border_color", border)
		material.set_shader_parameter("emissive", emissive)

		var label: Label3D = entry["label"]
		label.text = node.get_short_label()
		label.modulate = label_color

		var holder: Node3D = entry["holder"]
		var lift := 0.22 if node.id == _hover_id else 0.0
		holder.position.y = float(entry["base_y"]) + lift


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
		if not _in_hex(dx, dz, layout.hex_radius):
			continue
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## 把地形顶点烘成高度场。
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
	var half_depth := layout.get_row_step() * 0.5
	for node in run.graph.nodes:
		var center := _raw_hex_center(node)
		min_x = minf(min_x, center.x - layout.hex_radius)
		max_x = maxf(max_x, center.x + layout.hex_radius)
		min_z = minf(min_z, center.y - half_depth)
		max_z = maxf(max_z, center.y + half_depth)
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


## 六边形脚印内的地表最低点，用来决定棱柱向下延伸多深。
func _footprint_low(center_x: float, center_z: float) -> float:
	var height := _sample_height(center_x, center_z)
	var radius := layout.hex_radius * FOOTPRINT_RATIO
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var sample_x := center_x + cos(angle) * radius
		var sample_z := center_z + sin(angle) * radius
		height = minf(height, _sample_height(sample_x, sample_z))
	return height


## 双线性采样高度场。
func _sample_height(x: float, z: float) -> float:
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
	var v00 := _field[z0 * _field_columns + x0]
	var v10 := _field[z0 * _field_columns + x1]
	var v01 := _field[z1 * _field_columns + x0]
	var v11 := _field[z1 * _field_columns + x1]
	var top := lerpf(v00, v10, tx)
	var bottom := lerpf(v01, v11, tx)
	return lerpf(top, bottom, tz)


## 未加棋盘偏移的六边形中心。
func _raw_hex_center(node: MapNode) -> Vector2:
	var x := float(node.column) * layout.get_column_step()
	var z := (float(node.row) + 0.5 * float(node.column & 1)) * layout.get_row_step()
	return Vector2(x, z)


## 加上棋盘偏移后的六边形中心。
func _hex_center(node: MapNode) -> Vector2:
	return _raw_hex_center(node) + _board_offset


## flat-top 六边形的点内测试。
func _in_hex(dx: float, dz: float, radius: float) -> bool:
	var half := SQRT3 * 0.5 * radius
	var ax := absf(dx)
	var az := absf(dz)
	return az <= half + 0.0001 and SQRT3 * 0.5 * ax + 0.5 * az <= half + 0.0001


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

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = _unit_mesh
		var low := _footprint_low(center.x, center.y)
		var depth := maxf(base_y - low + 0.8, run.config.hex_height)
		mesh_instance.scale = Vector3(layout.hex_radius, depth, layout.hex_radius)
		var material := ShaderMaterial.new()
		material.shader = HEX_SHADER
		material.set_shader_parameter("border_width", 0.085)
		mesh_instance.material_override = material
		holder.add_child(mesh_instance)

		var label := Label3D.new()
		label.name = "Label"
		label.font = _label_font
		label.font_size = 64
		label.pixel_size = 0.012
		label.outline_size = 12
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
		label.modulate = Color.WHITE
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0.0, 0.6, 0.0)
		label.text = node.get_short_label()
		holder.add_child(label)

		entry["holder"] = holder
		entry["mesh"] = mesh_instance
		entry["material"] = material
		entry["label"] = label
		entry["base_y"] = base_y
		_tiles[node.id] = entry


func _clear_tiles() -> void:
	for node_id in _tiles.keys():
		var entry: Dictionary = _tiles[node_id]
		var holder: Node3D = entry.get("holder")
		if is_instance_valid(holder):
			holder.free()
	_tiles.clear()


## 单位六边形棱柱：顶面 y=0，底面 y=-1，外接圆半径 1。
func _build_unit_hex() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		ring.append(Vector3(cos(angle), 0.0, sin(angle)))

	# 顶面。
	for index in range(6):
		var a := ring[index]
		var b := ring[(index + 1) % 6]
		_add_vertex(surface, Vector3.ZERO, Vector3.UP, _top_uv(Vector3.ZERO))
		_add_vertex(surface, a, Vector3.UP, _top_uv(a))
		_add_vertex(surface, b, Vector3.UP, _top_uv(b))

	# 侧面，从顶面一直向下延伸到地表以下。
	for index in range(6):
		var a := ring[index]
		var b := ring[(index + 1) % 6]
		var normal := Vector3(a.x + b.x, 0.0, a.z + b.z).normalized()
		var a_bottom := a - Vector3.UP
		var b_bottom := b - Vector3.UP
		_add_vertex(surface, a, normal, Vector2(0.0, 0.0))
		_add_vertex(surface, b, normal, Vector2(1.0, 0.0))
		_add_vertex(surface, b_bottom, normal, Vector2(1.0, 1.0))
		_add_vertex(surface, a, normal, Vector2(0.0, 0.0))
		_add_vertex(surface, b_bottom, normal, Vector2(1.0, 1.0))
		_add_vertex(surface, a_bottom, normal, Vector2(0.0, 1.0))

	# 底面。
	for index in range(6):
		var a := ring[index]
		var b := ring[(index + 1) % 6]
		_add_vertex(surface, Vector3.DOWN, Vector3.DOWN, Vector2.ZERO)
		_add_vertex(surface, b - Vector3.UP, Vector3.DOWN, Vector2.ZERO)
		_add_vertex(surface, a - Vector3.UP, Vector3.DOWN, Vector2.ZERO)

	return surface.commit()


func _add_vertex(surface: SurfaceTool, vertex: Vector3, normal: Vector3, uv: Vector2) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(vertex)


## 顶面 UV 使用单位六边形的局部 x/z，供六边形边框着色器使用。
func _top_uv(vertex: Vector3) -> Vector2:
	return Vector2(vertex.x, vertex.z)


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


## 盒式模糊，输出仍然不低于原值是被禁止的，因此这里只做纯平均。
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
