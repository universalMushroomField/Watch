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

const PAN_THRESHOLD := 5.0
var _hover_id := -1
var _left_pressed := false
var _panning := false
var _press_position := Vector2.ZERO


func set_run(map_run: MapRun) -> void:
	run = map_run
	_left_pressed = false
	_panning = false
	_hover_id = -1
	if hex_layer != null:
		hex_layer.set_hover_id(-1)
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if run == null:
		return
	var camera := hex_layer.camera as MapCamera if hex_layer != null else null
	if event is InputEventMouseMotion and camera != null and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		camera.orbit_drag(event.relative.x, event.relative.y)
		_left_pressed = false
		_update_hover(Vector2(-100000.0, -100000.0))
		accept_event()
		return
	if event is InputEventMouseButton and camera != null and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				camera.zoom_at(_viewport_position(event.position))
				_update_hover(event.position)
				accept_event()
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				camera.reset_zoom(hex_layer.get_map_center())
				_update_hover(event.position)
				accept_event()
				return
	if event is InputEventMouseMotion:
		if _left_pressed and camera != null and camera.is_zoomed() and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var previous: Vector2 = event.position - event.relative
			if not _panning and event.position.distance_to(_press_position) >= PAN_THRESHOLD:
				_panning = true
				previous = _press_position
			if _panning:
				camera.pan_drag(_viewport_position(event.position) - _viewport_position(previous))
				_update_hover(Vector2(-100000.0, -100000.0))
				mouse_default_cursor_shape = Control.CURSOR_DRAG
				accept_event()
				return
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_pressed = true
			_panning = false
			_press_position = event.position
			accept_event()
		elif _left_pressed:
			_left_pressed = false
			var was_panning := _panning
			_panning = false
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			_update_hover(event.position)
			accept_event()
			if not was_panning and event.position.distance_to(_press_position) < PAN_THRESHOLD:
				var node := _node_at(event.position)
				if node != null:
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
	return hex_layer.node_at_screen(_viewport_position(local_position))


func _viewport_position(local_position: Vector2) -> Vector2:
	if viewport_container == null or sub_viewport == null:
		return local_position
	var container_size := viewport_container.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		return local_position
	var global_position := get_global_rect().position + local_position
	var pixel := global_position - viewport_container.get_global_rect().position
	var scale := Vector2(sub_viewport.size) / container_size
	return pixel * scale
