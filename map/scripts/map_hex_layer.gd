## 将六边形顶点网络投放到地形和交互平面。
class_name MapHexLayer
extends Node3D

const SQRT3 := 1.7320508075688772
const PATH_LIFT := 0.035
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
var run: MapRun
var layout: HexLayout

var _tiles := {}
var _hover_id := -1
var _label_font: SystemFont
var _surface := MapSurfaceSampler.new()
var _board_offset := Vector2.ZERO
var _board_angle := 0.0
var _zoom_height_blend := 0.0
var _interaction_plane := 0.0
var _attachment_root: Node3D
var _attachment_paths: MeshInstance3D
var _interaction_paths: MeshInstance3D
var _vertical_trim: MeshInstance3D
var _paths: Array[PackedVector3Array] = []

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


## 根据地形和相机可视范围计算棋盘布局。
func make_layout(config: MapConfig) -> HexLayout:
	_surface.build(terrain)
	var rect := _available_rect(config)
	var target := HexLayout.from_config(config)
	var target_radius := target.hex_radius
	var interior_columns := int(floor(rect.size.x / (SQRT3 * target_radius) - 2.5))
	var interior_rows := int(floor((rect.size.y / target_radius - 0.5) / 1.5))
	interior_columns = clampi(interior_columns, 2, target.columns)
	interior_rows = clampi(interior_rows, 2, target.rows)

	# 用实际列数重新拟合半径，保证棋盘完整落在可用矩形内。
	var span_columns := SQRT3 * (float(interior_columns) + 2.5)
	var span_rows := 1.5 * float(interior_rows) + 0.5
	var radius := minf(rect.size.x / span_columns, rect.size.y / span_rows)
	radius = minf(radius, target_radius)
	return HexLayout.new(interior_columns, interior_rows, radius)


## 显示当前幕的顶点网络。
func show_run(map_run: MapRun) -> void:
	_clear_tiles()
	run = map_run
	if run == null or run.graph == null:
		return
	layout = run.layout
	_board_angle = _camera_board_angle()
	_compute_board_offset(_available_rect(run.config))
	_interaction_plane = _surface.bounds.end.y + run.config.hex_lift
	_create_tiles()
	_create_paths()
	refresh()

## 按当前进度刷新标签和可达状态。
func _process(delta: float) -> void:
	if run == null or not camera is MapCamera:
		return
	var target: float = camera.get_zoom_progress()
	if _zoom_height_blend != target:
		_zoom_height_blend = move_toward(_zoom_height_blend, target, delta * 5.0)
		_update_node_positions()


func _update_node_positions() -> void:
	for entry: Dictionary in _tiles.values():
		var attachment: Node3D = entry["attachment"]
		var holder: Node3D = entry["holder"]
		var point := attachment.global_position
		point.y = lerpf(_interaction_plane, point.y, _zoom_height_blend)
		holder.global_position = point
	_update_paths()
	_update_vertical_trim()

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

	_update_node_positions()



## 设置鼠标悬停的节点编号，-1 表示没有。
func set_hover_id(node_id: int) -> void:
	if _hover_id == node_id:
		return
	_hover_id = node_id
	refresh()


## 当前悬停的节点编号。
func get_hover_id() -> int:
	return _hover_id


## 底图在相机参考平面上的中心。
func get_map_center() -> Vector3:
	if terrain == null or terrain.mesh == null:
		return global_position
	var center := terrain.mesh.get_aabb().get_center()
	return terrain.to_global(Vector3(center.x, 0.0, center.z))


## 已经生成的六边形数量。
func get_tile_count() -> int:
	return _tiles.size()


func get_path_count() -> int:
	return _paths.size()


## 返回离光标最近且位于点击范围内的顶点地点。
func node_at_screen(screen_position: Vector2) -> MapNode:
	if run == null or run.graph == null or camera == null:
		return null

	var best: MapNode = null
	var best_distance := INF
	for node in run.graph.nodes:
		var entry: Dictionary = _tiles.get(node.id, {})
		if entry.is_empty():
			continue
		var holder: Node3D = entry["holder"]
		var position := holder.global_position
		if camera.is_position_behind(position):
			continue
		var vertex_screen := camera.unproject_position(position)
		var label: Label3D = entry["label"]
		var label_screen := camera.unproject_position(label.global_position)
		var radius_point := position + camera.global_basis.x.normalized() * layout.hex_radius
		var radius := clampf(vertex_screen.distance_to(camera.unproject_position(radius_point)) * 0.35, 12.0, 34.0)
		var distance := minf(screen_position.distance_to(vertex_screen), screen_position.distance_to(label_screen))
		if distance <= radius and distance < best_distance:
			best_distance = distance
			best = node
	return best

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


func _compute_board_offset(rect: Rect2) -> void:
	var first := _vertex_offset(run.graph.nodes[0])
	var bounds := Rect2(first, Vector2.ZERO)
	for node in run.graph.nodes:
		bounds = bounds.expand(_vertex_offset(node))
	_board_offset = rect.get_center() - bounds.get_center()


func _vertex_offset(node: MapNode) -> Vector2:
	var scale := layout.hex_radius * 0.5
	return _rotate(Vector2(node.vertex.x * SQRT3, node.vertex.y) * scale, _board_angle)

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


func _node_vertex(node: MapNode) -> Vector2:
	return _vertex_offset(node) + _board_offset

func _create_tiles() -> void:
	_attachment_root = Node3D.new()
	_attachment_root.name = "AttachmentPoints"
	tiles_root.add_child(_attachment_root)
	var marker := SphereMesh.new()
	marker.radius = 0.09
	marker.height = 0.18
	marker.material = _line_material(Color(0.3, 0.74, 0.81))
	var interactive_marker := SphereMesh.new()
	interactive_marker.radius = 0.14
	interactive_marker.height = 0.28
	interactive_marker.material = _line_material(Color(1.0, 0.78, 0.4))
	_tiles.clear()
	if run == null or run.graph == null:
		return
	for node in run.graph.nodes:
		var entry := {}
		var center := _node_vertex(node)
		var ground := _surface.height_at(center)
		if ground == -INF:
			ground = _surface.bounds.end.y
		var attachment := MeshInstance3D.new()
		attachment.name = "Attachment_%d" % node.id
		attachment.mesh = marker
		attachment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_attachment_root.add_child(attachment)
		attachment.global_position = Vector3(center.x, ground, center.y)

		var holder := Node3D.new()
		holder.name = "Hex_%d" % node.id
		tiles_root.add_child(holder)
		var dot := MeshInstance3D.new()
		dot.mesh = interactive_marker
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(dot)

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
		entry["attachment"] = attachment
		_tiles[node.id] = entry


func _create_paths() -> void:
	_attachment_paths = _make_path_mesh("AttachmentPaths", Color(0.28, 0.66, 0.75, 0.25), 0)
	_interaction_paths = _make_path_mesh("InteractionPaths", Color(1.0, 0.78, 0.4), 1)
	_vertical_trim = _make_path_mesh("edge_beautify_vertical", Color.WHITE, 0)
	var trim_material := _vertical_trim.material_override as StandardMaterial3D
	trim_material.vertex_color_use_as_albedo = true
	for node in run.graph.nodes:
		var attachment: Node3D = _tiles[node.id]["attachment"]
		for neighbor_id in node.neighbor_ids:
			if neighbor_id <= node.id:
				continue
			var end: Node3D = _tiles[neighbor_id]["attachment"]
			var a := attachment.global_position
			var b := end.global_position
			_paths.append(_surface.trace(a, b))
	_attachment_paths.mesh = _build_paths_mesh(true)
	_update_paths()


func _make_path_mesh(node_name: String, color: Color, priority: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var material := _line_material(color)
	# 两组路径都进入透明队列，按优先级绘制且互不写入深度。
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = priority
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tiles_root.add_child(instance)
	return instance


func _line_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _update_paths() -> void:
	if _interaction_paths == null:
		return
	_interaction_paths.mesh = _build_paths_mesh(false)


func _update_vertical_trim() -> void:
	if _vertical_trim == null:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var has_segments := false
	for entry: Dictionary in _tiles.values():
		var holder: Node3D = entry["holder"]
		var attachment: Node3D = entry["attachment"]
		if holder.global_position.distance_squared_to(attachment.global_position) <= 0.000001:
			continue
		has_segments = true
		surface.set_color(Color(1.0, 0.78, 0.4, 1.0))
		surface.add_vertex(tiles_root.to_local(holder.global_position))
		surface.set_color(Color(1.0, 0.78, 0.4, 0.0))
		surface.add_vertex(tiles_root.to_local(attachment.global_position))
	_vertical_trim.mesh = surface.commit() if has_segments else null


func _build_paths_mesh(attached: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for path in _paths:
		if attached:
			for i in range(path.size() - 1):
				surface.add_vertex(tiles_root.to_local(path[i] + Vector3.UP * PATH_LIFT))
				surface.add_vertex(tiles_root.to_local(path[i + 1] + Vector3.UP * PATH_LIFT))
		else:
			for endpoint in [path[0], path[path.size() - 1]]:
				endpoint.y = lerpf(_interaction_plane, endpoint.y, _zoom_height_blend) + PATH_LIFT * _zoom_height_blend
				surface.add_vertex(tiles_root.to_local(endpoint))
	return surface.commit()

func _clear_tiles() -> void:
	for entry: Dictionary in _tiles.values():
		var holder: Node3D = entry["holder"]
		holder.free()
	_tiles.clear()
	for node in [_attachment_root, _attachment_paths, _interaction_paths, _vertical_trim]:
		if is_instance_valid(node):
			node.free()
	_attachment_root = null
	_attachment_paths = null
	_interaction_paths = null
	_vertical_trim = null
	_paths.clear()
