## 六边形棋盘的鼠标交互层。
##
## 这一层是 Control，盖在 [SubViewportContainer] 上：它把本地坐标换算成
## SubViewport 像素，再交给 [MapHexLayer] 做射线拾取。这样鼠标事件不会被
## 三维视口吞掉，也不需要把相机输入打开。
class_name MapBoardInput
extends Control

## 点击了一个可以前往的地点。
signal node_pressed(node: MapNode)

## 负责绘制和拾取的六边形层。
@export var hex_layer: MapHexLayer
## 承载三维视口的容器。
@export var viewport_container: SubViewportContainer
## 三维视口。
@export var sub_viewport: SubViewport

var run: MapRun

var _hover_id := -1


func set_run(map_run: MapRun) -> void:
	run = map_run
	_hover_id = -1
	if hex_layer != null:
		hex_layer.set_hover_id(-1)
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if run == null:
		return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
			var node := _node_at(button.position)
			if node != null:
				accept_event()
				node_pressed.emit(node)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_update_hover(Vector2(-100000.0, -100000.0))


func _update_hover(local_position: Vector2) -> void:
	var node := _node_at(local_position)
	var node_id := node.id if node != null else -1
	if node_id == _hover_id:
		return
	_hover_id = node_id
	if hex_layer != null:
		hex_layer.set_hover_id(node_id)
	var can_press := node != null and run != null and run.can_travel_to(node.id)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_press else Control.CURSOR_ARROW


func _node_at(local_position: Vector2) -> MapNode:
	if run == null or hex_layer == null or viewport_container == null or sub_viewport == null:
		return null
	var container_size := viewport_container.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		return null
	var global_position := get_global_rect().position + local_position
	var pixel := global_position - viewport_container.get_global_rect().position
	var scale := Vector2(sub_viewport.size) / container_size
	return hex_layer.node_at_screen(pixel * scale)
