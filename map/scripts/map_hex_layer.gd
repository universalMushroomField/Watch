## 将六边形顶点网络投放到地形和交互平面。
class_name MapHexLayer
extends Node3D

const SQRT3 := 1.7320508075688772
const PATH_LIFT := 0.035
## 悬停路径比基础折线再抬高一点，避免两层线在斜视时穿插闪烁。
const HOVER_PATH_LIFT := 0.012
## 玩家所在节点标签上下浮动的幅度与速度。
const LABEL_BOB_HEIGHT := 0.07
const LABEL_BOB_SPEED := 3.2
const ATTACHMENT_PATH := preload("res://map/templates/path/attachment_path.tscn")
const INTERACTION_PATH := preload("res://map/templates/path/interaction_path.tscn")
const HOVER_PATH := preload("res://map/templates/path/hover_path.tscn")
const VERTICAL_TRIM := preload("res://map/templates/path/vertical_trim.tscn")
const HIGHLIGHT := preload("res://map/templates/node/highlight.tscn")

const LOCATION_SCENES := {
	MapNode.Type.START: preload("res://map/templates/node/start.tscn"),
	MapNode.Type.BATTLE: preload("res://map/templates/node/battle.tscn"),
	MapNode.Type.ELITE: preload("res://map/templates/node/elite.tscn"),
	MapNode.Type.EVENT: preload("res://map/templates/node/event.tscn"),
	MapNode.Type.SHOP: preload("res://map/templates/node/shop.tscn"),
	MapNode.Type.REST: preload("res://map/templates/node/rest.tscn"),
	MapNode.Type.HUB: preload("res://map/templates/node/hub.tscn"),
	MapNode.Type.BOSS: preload("res://map/templates/node/boss.tscn"),
}


## 地形网格，用来读取地表高度。
@export var terrain: MeshInstance3D
## 相机，用来计算可视范围。
@export var camera: Camera3D
## 六边形节点的父节点，留空时自动创建。
@export var tiles_root: Node3D
var run: MapRun
var layout: HexLayout

var _locations: Dictionary[int, MapLocation] = {}
var _hover_id := -1
var _surface := MapSurfaceSampler.new()
var _board_offset := Vector2.ZERO
var _board_angle := 0.0
var _zoom_height_blend := 0.0
var _path_view_depth := Vector3.BACK
var _interaction_plane := 0.0
var _attachment_paths: MapPath
var _interaction_paths: MapPath
var _hover_attached_path: MapPath
var _hover_plane_path: MapPath
var _vertical_trim: MapPath
var _paths: Array[PackedVector3Array] = []
## 悬停节点时额外画出的「走过去」路径。
var _hover_paths: Array[PackedVector3Array] = []
var _bob_time := 0.0

func _ready() -> void:
	if terrain == null:
		terrain = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if terrain is MapTerrainModel:
		(terrain as MapTerrainModel).terrain_rebuilt.connect(_on_terrain_rebuilt)
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if tiles_root == null:
		tiles_root = Node3D.new()
		tiles_root.name = "Tiles"
		add_child(tiles_root)
	_apply_palette()


func _on_terrain_rebuilt() -> void:
	if run != null:
		_surface.build(terrain)
		show_run(run)


## 根据地形和相机可视范围计算棋盘布局，几何拟合见 [method HexLayout.fit]。
func make_layout(config: MapConfig) -> HexLayout:
	_surface.build(terrain)
	return HexLayout.fit(_available_rect(config), config)


## 显示当前幕的顶点网络。
func show_run(map_run: MapRun) -> void:
	_clear_tiles()
	run = map_run
	if run == null or run.graph == null:
		_update_terrain_regions()
		return
	layout = run.layout
	_board_angle = _camera_board_angle()
	_compute_board_offset(_available_rect(run.config))
	_interaction_plane = _surface.bounds.end.y + run.config.hex_lift
	_create_tiles()
	_create_paths()
	_update_node_positions()
	refresh()

## 按当前进度刷新每个地点的状态，并让玩家所在节点的标签缓缓浮动。
func _process(delta: float) -> void:
	_bob_time += delta
	_update_label_bob()
	if run == null or not camera is MapCamera:
		return
	var target: float = camera.get_zoom_progress()
	var view_depth := camera.global_basis.z.normalized()
	if not _path_view_depth.is_equal_approx(view_depth):
		_path_view_depth = view_depth
		_update_paths()
		_update_vertical_trim()
	if _zoom_height_blend != target:
		_zoom_height_blend = move_toward(_zoom_height_blend, target, delta * 5.0)
		_update_node_positions()


func _update_node_positions() -> void:
	for location in _locations.values():
		var attachment: Node3D = location.attachment
		var holder: Node3D = location.interaction
		var point := attachment.global_position
		point.y = lerpf(_interaction_plane, point.y, _zoom_height_blend)
		holder.global_position = point
		location.update_zoom_scale(_zoom_scale())
	_update_paths()
	_update_vertical_trim()

## 按当前进度刷新每个地点的状态：球体、标签与标记环一起换色。
func refresh() -> void:
	if run == null or run.graph == null:
		return
	_update_terrain_regions()
	var reachable := {}
	for node in run.get_reachable_nodes():
		reachable[node.id] = true

	for node in run.graph.nodes:
		var location := get_location(node.id)
		if location == null:
			continue
		location.label.text = node.get_short_label()
		location.apply_state(_node_state(node, reachable), node.id == _hover_id)


## 节点此刻的状态，优先级：玩家所在 > 已访问 > 可前往 > 还没连过来。
func _node_state(node: MapNode, reachable: Dictionary) -> MapLocation.State:
	if node.id == run.current_id:
		return MapLocation.State.CURRENT
	if node.visited:
		return MapLocation.State.VISITED
	if reachable.has(node.id):
		return MapLocation.State.REACHABLE
	return MapLocation.State.UNREACHED


## 玩家所在节点的标签上下浮动，配合旋转虚线环强调「你在这里」。
func _update_label_bob() -> void:
	if run == null:
		return
	var current := get_location(run.current_id)
	var offset := sin(_bob_time * LABEL_BOB_SPEED) * LABEL_BOB_HEIGHT
	for location in _locations.values():
		location.set_label_offset(offset if location == current else 0.0)

## 按地表附着点划分区域，避免节点悬浮高度影响配色。
func _update_terrain_regions() -> void:
	var material := terrain.material_override as ShaderMaterial if terrain != null else null
	if material == null:
		return
	if run == null or run.graph == null or run.graph.nodes.is_empty():
		material.set_shader_parameter("region_span_count", 0)
		return
	var nodes := run.graph.nodes
	var spans: Array[Color] = []
	var metadata: Array[Color] = []
	var seen := {}
	for seed: MapNode in nodes:
		if seen.has(seed.id):
			continue
		var pending: Array[MapNode] = [seed]
		var points := PackedVector2Array()
		seen[seed.id] = true
		while not pending.is_empty():
			var node: MapNode = pending.pop_back()
			var point: Vector3 = _locations[node.id].attachment.global_position
			points.append(Vector2(point.x, point.z))
			spans.append(Color(point.x, point.z, point.x, point.z))
			metadata.append(Color(float(seed.visited), 0, 0, 1))
			for neighbor_id in node.neighbor_ids:
				if seen.has(neighbor_id):
					continue
				var neighbor := run.graph.get_node_by_id(neighbor_id)
				if neighbor.visited == seed.visited:
					seen[neighbor_id] = true
					pending.append(neighbor)
		if points.size() >= 2:
			var hull := Geometry2D.convex_hull(points)
			for i in range(hull.size() - 1):
				var a := hull[i]
				var b := hull[i + 1]
				spans.append(Color(a.x, a.y, b.x, b.y))
				metadata.append(Color(float(seed.visited), 1, float(i == hull.size() - 2), 1))
	var image := Image.create_empty(spans.size(), 2, false, Image.FORMAT_RGBAF)
	for i in range(spans.size()):
		image.set_pixel(i, 0, spans[i])
		image.set_pixel(i, 1, metadata[i])
	material.set_shader_parameter("region_spans", ImageTexture.create_from_image(image))
	material.set_shader_parameter("region_span_count", spans.size())


## 将地图材质与灯光接入美术色板。
func _apply_palette() -> void:
	var light := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light != null:
		light.light_color = ArtPalette.color(ArtPalette.LIGHT)

	var background := get_node_or_null("MeshInstance3D2") as MeshInstance3D
	if background != null:
		var background_material := StandardMaterial3D.new()
		background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

		background_material.albedo_color = ArtPalette.color(ArtPalette.BACKGROUND)
		background.material_override = background_material


## 设置鼠标悬停的节点编号，-1 表示没有。悬停已探索节点时会亮出从玩家位置走过去的路径。
func set_hover_id(node_id: int) -> void:
	if _hover_id == node_id:
		return
	_hover_id = node_id
	_rebuild_hover_path()
	refresh()


## 悬停节点时高亮「从玩家脚下走过去」的整条路径：沿已探索节点走，最后一步进目标。
func _rebuild_hover_path() -> void:
	_hover_paths.clear()
	if run != null and run.graph != null and _hover_id >= 0 and _hover_id != run.current_id:
		var ids := run.find_path_to(_hover_id)
		for index in range(ids.size() - 1):
			var from := get_location(ids[index])
			var to := get_location(ids[index + 1])
			if from == null or to == null:
				_hover_paths.clear()
				break
			_hover_paths.append(_surface.trace(from.attachment.global_position, to.attachment.global_position))
	_update_paths()


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
	return _locations.size()


func get_path_count() -> int:
	return _paths.size()


## 返回离光标最近且位于点击范围内的顶点地点。
func node_at_screen(screen_position: Vector2) -> MapNode:
	if run == null or run.graph == null or camera == null:
		return null

	var best: MapNode = null
	var best_distance := INF
	for node in run.graph.nodes:
		var location := get_location(node.id)
		if location == null:
			continue
		var holder: Node3D = location.interaction
		var position := holder.global_position
		if camera.is_position_behind(position):
			continue
		var vertex_screen := camera.unproject_position(position)
		var label: Label3D = location.label
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

func get_location(node_id: int) -> MapLocation:
	return _locations.get(node_id)


func _create_tiles() -> void:
	var project_font := load(ProjectSettings.get_setting("gui/theme/custom_font")) as Font
	for node in run.graph.nodes:
		var scene: PackedScene = LOCATION_SCENES[node.type]
		var location := scene.instantiate() as MapLocation
		location.name = "Hex_%d" % node.id
		tiles_root.add_child(location)
		var center := _node_vertex(node)
		var ground := _surface.height_at(center)
		if ground == -INF:
			ground = _surface.bounds.end.y
		location.attachment.global_position = Vector3(center.x, ground, center.y)
		if location.label.font == null:
			location.label.font = project_font
		var highlight := HIGHLIGHT.instantiate() as MapHighlight
		location.interaction.add_child(highlight)
		highlight.position = location.label.position
		location.highlight = highlight
		_locations[node.id] = location


func _create_paths() -> void:
	_attachment_paths = _instantiate_path(ATTACHMENT_PATH)
	_interaction_paths = _instantiate_path(INTERACTION_PATH)
	_hover_attached_path = _instantiate_path(HOVER_PATH, ArtPalette.PATH_HOVER, ArtPalette.PATH_HOVER_ALPHA)
	_hover_plane_path = _instantiate_path(HOVER_PATH, ArtPalette.PATH_HOVER, ArtPalette.PATH_HOVER_ALPHA)
	_vertical_trim = _instantiate_path(VERTICAL_TRIM)
	if camera != null:
		_path_view_depth = camera.global_basis.z.normalized()
	for node in run.graph.nodes:
		var attachment: Node3D = _locations[node.id].attachment
		for neighbor_id in node.neighbor_ids:
			if neighbor_id <= node.id:
				continue
			var end: Node3D = _locations[neighbor_id].attachment
			var a := attachment.global_position
			var b := end.global_position
			_paths.append(_surface.trace(a, b))


func _instantiate_path(scene: PackedScene, palette_index: int = -1, line_alpha: float = -1.0) -> MapPath:
	var path := scene.instantiate() as MapPath
	if palette_index >= 0:
		path.palette_index = palette_index
	if line_alpha >= 0.0:
		path.line_alpha = line_alpha
	tiles_root.add_child(path)
	return path


func _zoom_scale() -> float:
	return lerpf(1.0, 1.25, _zoom_height_blend)


func _update_paths() -> void:
	if _interaction_paths == null:
		return
	var attached := SurfaceTool.new()
	var interaction := SurfaceTool.new()
	var hover_attached := SurfaceTool.new()
	var hover_plane := SurfaceTool.new()
	for surface in [attached, interaction, hover_attached, hover_plane]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var factor := _zoom_scale()
	for path in _paths:
		_draw_path(path, _attachment_paths, _interaction_paths, attached, interaction, factor, 0.0)
	for path in _hover_paths:
		_draw_path(path, _hover_attached_path, _hover_plane_path, hover_attached, hover_plane, factor, HOVER_PATH_LIFT)
	_attachment_paths.mesh = attached.commit()
	_interaction_paths.mesh = interaction.commit()
	if _hover_attached_path != null and _hover_plane_path != null:
		var has_hover := not _hover_paths.is_empty()
		_hover_attached_path.mesh = hover_attached.commit() if has_hover else null
		_hover_plane_path.mesh = hover_plane.commit() if has_hover else null


## 一条贴地折线画两层：贴地表的一层，和俯视时抬到交互平面的那一层。
func _draw_path(path: PackedVector3Array, attached_path: MapPath, plane_path: MapPath,
		attached: SurfaceTool, plane: SurfaceTool, factor: float, height_bias: float) -> void:
	if path.size() < 2 or attached_path == null or plane_path == null:
		return
	var lift := PATH_LIFT + height_bias
	for i in range(path.size() - 1):
		attached_path.add_segment(attached, path[i] + Vector3.UP * lift, path[i + 1] + Vector3.UP * lift,
			_path_view_depth, factor)
	var a := path[0]
	var b := path[path.size() - 1]
	a.y = lerpf(_interaction_plane, a.y + lift, _zoom_height_blend)
	b.y = lerpf(_interaction_plane, b.y + lift, _zoom_height_blend)
	plane_path.add_segment(plane, a, b, _path_view_depth, factor)


func _update_vertical_trim() -> void:
	if _vertical_trim == null:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for location in _locations.values():
		_vertical_trim.add_segment(surface, location.interaction.global_position,
			location.attachment.global_position, _path_view_depth, _zoom_scale(), 0.0)
	_vertical_trim.mesh = surface.commit()


func _clear_tiles() -> void:
	for location in _locations.values():
		location.free()
	_locations.clear()
	for node in [_attachment_paths, _interaction_paths, _hover_attached_path, _hover_plane_path, _vertical_trim]:
		if is_instance_valid(node):
			node.free()
	_attachment_paths = null
	_interaction_paths = null
	_hover_attached_path = null
	_hover_plane_path = null
	_vertical_trim = null
	_paths.clear()
	_hover_paths.clear()
	_hover_id = -1
