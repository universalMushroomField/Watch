## 绘制自由网状地图，并把点击换算成节点。
class_name MapCanvas
extends Control

## 点击了某个节点。
signal node_pressed(node: MapNode)

const PADDING := 44.0
const NODE_RADIUS := 22.0
const FONT_SIZE := 16
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

	for node in run.graph.nodes:
		for neighbor_id in node.neighbor_ids:
			if neighbor_id < node.id:
				continue
			var neighbor := run.graph.get_node_by_id(neighbor_id)
			if neighbor == null:
				continue
			var is_active := (node.id == run.current_id and reachable.has(neighbor_id)) \
				or (neighbor_id == run.current_id and reachable.has(node.id))
			var color := ACTIVE_EDGE_COLOR if is_active else EDGE_COLOR
			draw_line(_node_center(node), _node_center(neighbor), color, 3.0 if is_active else 2.0, true)

	for node in run.graph.nodes:
		_draw_node(node, reachable.has(node.id))


func _draw_node(node: MapNode, is_reachable: bool) -> void:
	var center := _node_center(node)
	var color: Color = TYPE_COLORS.get(node.type, Color.GRAY)
	if node.visited:
		color = color.darkened(0.55)
	elif not is_reachable:
		color = color.darkened(0.2)
	if node.id == _hover_id and is_reachable:
		color = color.lightened(0.2)

	if node.id == run.current_id:
		draw_arc(center, NODE_RADIUS + 6.0, 0.0, TAU, 48, CURRENT_RING_COLOR, 3.0, true)
	elif is_reachable:
		draw_arc(center, NODE_RADIUS + 5.0, 0.0, TAU, 48, REACHABLE_RING_COLOR, 2.5, true)
	draw_circle(center, NODE_RADIUS, color)
	draw_arc(center, NODE_RADIUS, 0.0, TAU, 40, color.lightened(0.35), 2.0, true)

	var font := get_theme_default_font()
	var label := node.get_short_label()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var text_color := Color(1, 1, 1) if not node.visited else Color(0.8, 0.8, 0.8)
	draw_string(font, center + Vector2(-text_size.x / 2.0, text_size.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color)


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
	for index in range(run.graph.nodes.size() - 1, -1, -1):
		var node := run.graph.nodes[index]
		if _node_center(node).distance_to(point) <= NODE_RADIUS + 6.0:
			return node
	return null


func _is_reachable(node: MapNode) -> bool:
	if node == null:
		return false
	for reachable in run.get_reachable_nodes():
		if reachable.id == node.id:
			return true
	return false


## 把归一化坐标换算成控件内的像素坐标，y 轴向上对应地图更高层。
func _node_center(node: MapNode) -> Vector2:
	var inner := size - Vector2(PADDING, PADDING) * 2.0
	return Vector2(PADDING, PADDING) + Vector2(node.position.x * inner.x, (1.0 - node.position.y) * inner.y)
