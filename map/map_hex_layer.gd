## 在三维地形上绘制六边形蜂巢地图。
##
## 六边形不生成实体格子，也不画贴地的面：蜂巢的每条边是一根贴地的白色圆管，
## 每个顶点是一根白色短圆柱。格子内部保留原始地形，地图仍然是一整片地面，
## 只是被白色线框分割成一个个地点。
##
## 高度：先把地形 mesh 的顶点烘成 0.5m 的高度场，取邻域最大值保证不低于
## 地表，再做两次盒式模糊；圆管和圆柱直接采样原始地形高度，贴在 mesh 表面，
## 被地形挡住的部分由 shader 做柔和淡出。
class_name MapHexLayer
extends Node3D

const TUBE_SHADER: Shader = preload("res://map/shaders/hex_tube.gdshader")
const ROUTE_BLUR_SHADER: Shader = preload("res://map/shaders/terrain_route_blur.gdshader")
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
const TUBE_SEGMENTS := 6
## 圆管半径。
const TUBE_RADIUS := 0.15
## 圆管的侧面数，保持低多边形白模质感。
const TUBE_SIDES := 6
## 圆管中心离原始地表的距离，避免和地形 z-fighting。
const TUBE_CLEARANCE := 0.18
## 六边形顶点短圆柱的半径。
const POST_RADIUS := 0.24
## 六边形顶点短圆柱的高度。
const POST_HEIGHT := 0.60
## 短圆柱的侧面数。
const POST_SIDES := 10
## 路线模糊遮罩的分辨率。
const MASK_SIZE := 512
## 遮罩线条在世界空间中的半径（米）。
const MASK_RADIUS := 0.55

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
var _edge_meshes: Array[Dictionary] = []
var _hover_id := -1
var _post_count := 0
var _base_heights := {}

var _label_font: SystemFont
var _grid_root: Node3D
var _tube_mat: ShaderMaterial
var _terrain_blur: MeshInstance3D
var _terrain_blur_mat: ShaderMaterial

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
	_ensure_grid_root()
	_ensure_terrain_blur()
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
	_update_terrain_blur()
	_compute_base_heights()
	_create_tiles()
	_create_grid()
	refresh()


## 按当前进度刷新标签和可达状态。
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


## 已经生成的网格边数量。
func get_edge_count() -> int:
	return _edge_meshes.size()


## 已经生成的顶点圆柱数量。
func get_post_count() -> int:
	return _post_count


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


## 把地形顶点烘成高度场，并保留一份未平滑的原始值用于贴地网格线。
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


## 采样平滑后的高度（节点标记和拾取使用）。
func _sample_height(x: float, z: float) -> float:
	return _sample_field(_field, x, z)


## 采样未平滑的地表高度（网格线贴地使用）。
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


func _point_key(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x * 100.0), roundi(point.y * 100.0))


## 生成和地形共用 mesh 的轻微模糊层；只在地图路线附近显示。
func _ensure_terrain_blur() -> void:
	if terrain == null or terrain.mesh == null:
		return
	if _terrain_blur != null and is_instance_valid(_terrain_blur):
		return
	var parent := terrain.get_parent()
	if parent == null:
		parent = self
	_terrain_blur = MeshInstance3D.new()
	_terrain_blur.name = "TerrainRouteBlur"
	_terrain_blur.mesh = terrain.mesh
	_terrain_blur.transform = terrain.transform
	_terrain_blur.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_terrain_blur_mat = ShaderMaterial.new()
	_terrain_blur_mat.shader = ROUTE_BLUR_SHADER
	_terrain_blur_mat.render_priority = -100
	_terrain_blur.material_override = _terrain_blur_mat
	parent.add_child(_terrain_blur)


func _update_terrain_blur() -> void:
	if _terrain_blur_mat == null or run == null or run.graph == null or terrain == null or terrain.mesh == null:
		return
	var box: AABB = terrain.global_transform * terrain.mesh.get_aabb()
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return
	var mask_min := Vector2(box.position.x, box.position.z)
	var mask_size := Vector2(box.size.x, box.size.z)
	var image := Image.create(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_R8)
	image.fill(Color(0.0, 0.0, 0.0))
	var radius_px := clampf(MASK_RADIUS / minf(mask_size.x, mask_size.y) * float(MASK_SIZE), 4.0, 32.0)
	var seen := {}
	for node in run.graph.nodes:
		var center := _hex_center(node)
		for index in range(6):
			var a := _hex_corner(center, index)
			var b := _hex_corner(center, (index + 1) % 6)
			var key := _edge_key(a, b)
			if seen.has(key):
				continue
			seen[key] = true
			_stamp_mask_segment(image, a, b, mask_min, mask_size, radius_px)
	_terrain_blur_mat.set_shader_parameter("route_mask", ImageTexture.create_from_image(image))
	_terrain_blur_mat.set_shader_parameter("mask_min", mask_min)
	_terrain_blur_mat.set_shader_parameter("mask_size", mask_size)


func _mask_pixel(point: Vector2, mask_min: Vector2, mask_size: Vector2) -> Vector2:
	return Vector2(
		(point.x - mask_min.x) / mask_size.x * float(MASK_SIZE),
		(point.y - mask_min.y) / mask_size.y * float(MASK_SIZE),
	)


func _stamp_mask_segment(image: Image, a: Vector2, b: Vector2, mask_min: Vector2, mask_size: Vector2, radius: float) -> void:
	var start := _mask_pixel(a, mask_min, mask_size)
	var end := _mask_pixel(b, mask_min, mask_size)
	var length := start.distance_to(end)
	var steps := maxi(1, int(ceil(length / maxf(1.0, radius * 0.35))))
	for step in range(steps + 1):
		_stamp_mask_point(image, a.lerp(b, float(step) / float(steps)), radius, mask_min, mask_size)


func _stamp_mask_point(image: Image, point: Vector2, radius: float, mask_min: Vector2, mask_size: Vector2) -> void:
	var pixel := _mask_pixel(point, mask_min, mask_size)
	var x0 := maxi(0, int(floor(pixel.x - radius)))
	var x1 := mini(MASK_SIZE - 1, int(ceil(pixel.x + radius)))
	var y0 := maxi(0, int(floor(pixel.y - radius)))
	var y1 := mini(MASK_SIZE - 1, int(ceil(pixel.y + radius)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(pixel)
			var value := 1.0 - smoothstep(radius * 0.2, radius, distance)
			if value <= 0.0:
				continue
			if value > image.get_pixel(x, y).r:
				image.set_pixel(x, y, Color(value, value, value))


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


## 沿蜂巢边界生成白色圆管，并在六边形顶点生成白色圆柱。
func _create_grid() -> void:
	_edge_meshes.clear()
	_post_count = 0
	if run == null or run.graph == null or _grid_root == null:
		return

	var edges := {}
	var vertices := {}
	for node in run.graph.nodes:
		var center := _hex_center(node)
		for index in range(6):
			var a := _hex_corner(center, index)
			var b := _hex_corner(center, index + 1)
			vertices[_point_key(a)] = a
			var key := _edge_key(a, b)
			if not edges.has(key):
				edges[key] = {"a": a, "b": b, "ids": [] as Array[int]}
			var ids: Array = edges[key]["ids"]
			if not ids.has(node.id):
				ids.append(node.id)

	for key in edges:
		var edge: Dictionary = edges[key]
		_create_tube(edge["a"], edge["b"], edge["ids"])
	_create_posts(vertices.values())


## 一条边是一串小圆管，采样点贴着原始地表走。
func _create_tube(a: Vector2, b: Vector2, ids: Array) -> void:
	var points: Array[Vector3] = []
	for segment in range(TUBE_SEGMENTS + 1):
		var t := float(segment) / float(TUBE_SEGMENTS)
		var point := a.lerp(b, t)
		var height := _sample_raw(point.x, point.y) + TUBE_CLEARANCE
		points.append(Vector3(point.x, height, point.y))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(TUBE_SEGMENTS):
		_add_tube_segment(surface, points[segment], points[segment + 1])

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GridEdge"
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = _tube_material()
	_grid_root.add_child(mesh_instance)
	_edge_meshes.append({"mesh": mesh_instance, "ids": ids})


## 在两个采样点之间补一段六棱柱圆管。
func _add_tube_segment(surface: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var direction := to - from
	if direction.length_squared() < 0.000001:
		return
	direction = direction.normalized()
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(direction).normalized()

	for index in range(TUBE_SIDES):
		var angle := TAU * float(index) / float(TUBE_SIDES)
		var next_angle := TAU * float(index + 1) / float(TUBE_SIDES)
		var offset_a := side * cos(angle) * TUBE_RADIUS + up * sin(angle) * TUBE_RADIUS
		var offset_b := side * cos(next_angle) * TUBE_RADIUS + up * sin(next_angle) * TUBE_RADIUS
		var normal_a := offset_a.normalized()
		var normal_b := offset_b.normalized()
		var p0 := from + offset_a
		var p1 := from + offset_b
		var p2 := to + offset_b
		var p3 := to + offset_a
		_add_vertex(surface, p0, normal_a, Vector2(0.0, 0.0))
		_add_vertex(surface, p2, normal_b, Vector2(1.0, 1.0))
		_add_vertex(surface, p1, normal_b, Vector2(1.0, 0.0))
		_add_vertex(surface, p0, normal_a, Vector2(0.0, 0.0))
		_add_vertex(surface, p3, normal_a, Vector2(0.0, 1.0))
		_add_vertex(surface, p2, normal_b, Vector2(1.0, 1.0))


## 每个六边形顶点放一根贴地短圆柱，盖住圆管接缝。
func _create_posts(points: Array) -> void:
	if points.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in points:
		var ground := _sample_raw(point.x, point.y)
		_add_post(surface, Vector3(point.x, ground, point.y))
		_post_count += 1

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GridPosts"
	mesh_instance.mesh = surface.commit()
	mesh_instance.material_override = _tube_material()
	_grid_root.add_child(mesh_instance)


func _add_post(surface: SurfaceTool, base: Vector3) -> void:
	var bottom := base + Vector3(0.0, -0.04, 0.0)
	var top := base + Vector3(0.0, POST_HEIGHT, 0.0)
	for index in range(POST_SIDES):
		var angle := TAU * float(index) / float(POST_SIDES)
		var next_angle := TAU * float(index + 1) / float(POST_SIDES)
		var dir_a := Vector3(cos(angle), 0.0, sin(angle))
		var dir_b := Vector3(cos(next_angle), 0.0, sin(next_angle))
		var bottom_a := bottom + dir_a * POST_RADIUS
		var bottom_b := bottom + dir_b * POST_RADIUS
		var top_a := top + dir_a * POST_RADIUS
		var top_b := top + dir_b * POST_RADIUS

		_add_vertex(surface, bottom_a, dir_a, Vector2(0.0, 0.0))
		_add_vertex(surface, top_b, dir_b, Vector2(1.0, 1.0))
		_add_vertex(surface, bottom_b, dir_b, Vector2(1.0, 0.0))
		_add_vertex(surface, bottom_a, dir_a, Vector2(0.0, 0.0))
		_add_vertex(surface, top_a, dir_a, Vector2(0.0, 1.0))
		_add_vertex(surface, top_b, dir_b, Vector2(1.0, 1.0))

		# 顶盖，朝上
		_add_vertex(surface, top, Vector3.UP, Vector2(0.5, 0.5))
		_add_vertex(surface, top_b, Vector3.UP, Vector2(0.5, 0.0))
		_add_vertex(surface, top_a, Vector3.UP, Vector2(0.0, 0.0))


func _tube_material() -> ShaderMaterial:
	if _tube_mat == null:
		_tube_mat = ShaderMaterial.new()
		_tube_mat.shader = TUBE_SHADER
		_tube_mat.set_shader_parameter("base_color", Color(0.98, 0.98, 0.98))
	return _tube_mat

func _clear_tiles() -> void:
	for node_id in _tiles.keys():
		var entry: Dictionary = _tiles[node_id]
		var holder: Node3D = entry.get("holder")
		if is_instance_valid(holder):
			holder.free()
	_tiles.clear()
	if _grid_root != null:
		for child in _grid_root.get_children():
			child.free()
	_edge_meshes.clear()


func _ensure_grid_root() -> void:
	if _grid_root != null:
		return
	_grid_root = Node3D.new()
	_grid_root.name = "Grid"
	tiles_root.add_child(_grid_root)


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