## 绘制放射状地图：Boss 在中心，其余节点按层环绕，边不会互相交叉。
class_name MapCanvas
extends Control

## 点击了某个节点。
signal node_pressed(node: MapNode)

const PADDING := 30.0
const MIN_NODE_RADIUS := 9.0
const MAX_NODE_RADIUS := 22.0
const EDGE_COLOR := Color(0.35, 0.39, 0.47)
const ACTIVE_EDGE_COLOR := Color(0.95, 0.72, 0.36)
const REACHABLE_RING_COLOR := Color(1.0, 0.85, 0.4)
const CURRENT_RING_COLOR := Color(1, 1, 1)
const TYPE_COLORS := {
	MapNode.Type.START: Color(0.55, 0.6, 0.68),
	MapNode.Type.BATTLE: Color(0.72, 0.35, 0.33),
	MapNode.Type.ELITE: Color(0.55, 0.27, 0.6),
	MapNode.Type.EVENT: Color(0.33, 0.5, 0.72),
	MapNode.Type.TREASURE: Color(0.8, 0.63, 0.25),
	MapNode.Type.SHOP: Color(0.3, 0.6, 0.42),
	MapNode.Type.REST: Color(0.3, 0.62, 0.6),
	MapNode.Type.BOSS: Color(0.82, 0.2, 0.28),
}

## 要显示的地图进度。
var run: MapRun
var _hover_id := -1


func _ready() -> void:
	resized.connect(queue_redraw)


## 切换或刷新当前显示的地图。
func set_run(map_run: MapRun) -> void:
	run = map_run
	_hover_id = -1
	queue_redraw()


func _draw() -> void:
	if run == null or run.graph == null:
		return
	var reachable := {}
	for node in run.get_reachable_nodes():
		reachable[node.id] = true
	var node_radius := _node_radius()

	for node in run.graph.nodes:
		for neighbor_id in node.neighbor_ids:
			if neighbor_id < node.id:
				continue
			var neighbor := run.graph.get_node_by_id(neighbor_id)
			if neighbor == null:
				continue
			var is_active := (reachable.has(node.id) and neighbor.visited) \
				or (reachable.has(neighbor_id) and node.visited)
			var color := ACTIVE_EDGE_COLOR if is_active else EDGE_COLOR
			var width := 3.5 if is_active else 2.0
			if run.graph.is_ring_link(node.id, neighbor_id):
				_draw_ring_edge(node, neighbor, color, width, node_radius)
			else:
				_draw_tree_edge(node, neighbor, color, width, node_radius)

	for node in run.graph.nodes:
		_draw_node(node, reachable.has(node.id), node_radius)


## 树边是径向直线，在两端节点圆外裁断。
func _draw_tree_edge(from_node: MapNode, to_node: MapNode, color: Color, width: float, node_radius: float) -> void:
	var from := _node_center(from_node)
	var to := _node_center(to_node)
	var direction := to - from
	var distance := direction.length()
	var trim := node_radius + 2.0
	if distance <= trim * 2.0:
		return
	direction /= distance
	draw_line(from + direction * trim, to - direction * trim, color, width, true)


## 同层弧线边沿该层椭圆绘制，只接触两端节点。
func _draw_ring_edge(from_node: MapNode, to_node: MapNode, color: Color, width: float, node_radius: float) -> void:
	var from_angle := _node_angle(from_node)
	var to_angle := _node_angle(to_node)
	var delta := wrapf(to_angle - from_angle, -PI, PI)
	if absf(delta) < 0.0001:
		return

	var extent := _map_extent()
	var radius_norm := from_node.position.distance_to(Vector2(0.5, 0.5))
	var rx := radius_norm * extent.x
	var ry := radius_norm * extent.y
	var center := size * 0.5
	var steps := maxi(10, int(absf(delta) * 32.0))
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var angle := from_angle + delta * float(index) / float(steps)
		points.append(center + Vector2(cos(angle) * rx, -sin(angle) * ry))

	# 裁掉落进节点圆里的采样点。
	var trim := node_radius + 2.0
	var from_center := _node_center(from_node)
	var to_center := _node_center(to_node)
	while points.size() > 2 and points[0].distance_to(from_center) < trim:
		points.remove_at(0)
	while points.size() > 2 and points[points.size() - 1].distance_to(to_center) < trim:
		points.remove_at(points.size() - 1)
	if points.size() >= 2:
		draw_polyline(points, color, width, true)


func _draw_node(node: MapNode, is_reachable: bool, node_radius: float) -> void:
	var center := _node_center(node)
	var color: Color = TYPE_COLORS.get(node.type, Color.GRAY)
	if node.visited:
		color = color.darkened(0.55)
	elif not is_reachable:
		color = color.darkened(0.2)
	if node.id == _hover_id and is_reachable:
		color = color.lightened(0.2)

	if node.id == run.current_id:
		draw_arc(center, node_radius + 6.0, 0.0, TAU, 48, CURRENT_RING_COLOR, 3.0, true)
	elif is_reachable:
		draw_arc(center, node_radius + 5.0, 0.0, TAU, 48, REACHABLE_RING_COLOR, 2.5, true)
	draw_circle(center, node_radius, color)
	draw_arc(center, node_radius, 0.0, TAU, 40, color.lightened(0.35), 2.0, true)

	var font := get_theme_default_font()
	var font_size := maxi(9, int(node_radius * 0.78))
	var label := node.get_short_label()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_color := Color(1, 1, 1) if not node.visited else Color(0.8, 0.8, 0.8)
	draw_string(font, center + Vector2(-text_size.x / 2.0, text_size.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _gui_input(event: InputEvent) -> void:
	if run == null:
		return
	if event is InputEventMouseMotion:
		var hovered := _find_node_at(event.position)
		var hovered_id := hovered.id if hovered != null else -1
		if hovered_id != _hover_id:
			_hover_id = hovered_id
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _is_reachable(hovered) else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var node := _find_node_at(event.position)
		if node != null:
			accept_event()
			node_pressed.emit(node)


func _find_node_at(point: Vector2) -> MapNode:
	if run == null or run.graph == null:
		return null
	var node_radius := _node_radius()
	for index in range(run.graph.nodes.size() - 1, -1, -1):
		var node := run.graph.nodes[index]
		if _node_center(node).distance_to(point) <= node_radius + 6.0:
			return node
	return null


func _is_reachable(node: MapNode) -> bool:
	if node == null:
		return false
	for reachable in run.get_reachable_nodes():
		if reachable.id == node.id:
			return true
	return false


## 根据环与环之间的间距自适应节点半径，层数多时自动缩小。
func _node_radius() -> float:
	var band_count := 2
	if run != null and run.graph != null:
		band_count = maxi(run.graph.get_band_count(), 2)
	var gap := _map_extent().y / float(2 * (band_count - 1))
	return clampf(gap * 0.34, MIN_NODE_RADIUS, MAX_NODE_RADIUS)


func _inner_size() -> Vector2:
	return size - Vector2(PADDING, PADDING) * 2.0


## 把归一化坐标映射到居中的椭圆区域。
func _node_center(node: MapNode) -> Vector2:
	var extent := _map_extent()
	var origin := (size - extent) * 0.5
	return origin + Vector2(node.position.x * extent.x, (1.0 - node.position.y) * extent.y)


## 地图区域尺寸：高度占满，宽度最多为高度的 1.5 倍。
func _map_extent() -> Vector2:
	var inner := _inner_size()
	var height := maxf(inner.y, 1.0)
	var width := minf(inner.x, height * 1.5)
	return Vector2(width, height)


## 节点在归一化坐标系里相对中心的角度。
func _node_angle(node: MapNode) -> float:
	return atan2(node.position.y - 0.5, node.position.x - 0.5)
