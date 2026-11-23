extends SceneTree
## 地图界面冒烟测试：实例化地图场景，沿路径走到 Boss，再进入下一幕。

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://map/templates/map_view.tscn")
	_check(scene != null, "地图场景可以加载")
	if scene == null:
		_finish()
		return

	var view = scene.instantiate()
	root.add_child(view)
	await process_frame
	await process_frame

	_check(view.run != null, "地图进度已创建")
	if view.run == null:
		_finish()
		return
	_check(view.run.get_visited_count() == 1, "开局只访问了起点")
	_check(is_zero_approx(view.run.get_decay_ratio()), "开局崩解度为 0")
	_check(view.content_pool.events.size() > 0, "内容池包含事件")
	_check(view.content_pool.shop_stock != null, "内容池包含商店库存")
	_check(view.run_state != null, "单局状态已接入")
	_check(view.run.layout != null, "地图使用六边形布局")
	_check(view._hex_layer != null, "六边形层已创建")
	_check(view._hex_layer._tiles.size() == view.run.graph.get_node_count(), "每个节点都生成了六边形")
	_check(view._hex_layer.get_wall_count() > 0, "六边形边界生成了墙")
	var above_surface := true
	for node in view.run.graph.nodes:
		var center: Vector2 = view._hex_layer._hex_center(node)
		var raw: float = view._hex_layer._footprint_max(center.x, center.y)
		var base_y: float = float(view._hex_layer._base_heights.get(node.id, -100000.0))
		if base_y < raw + view.run.config.hex_lift - 0.001:
			above_surface = false
	_check(above_surface, "所有六边形都高于地表并整体抬升")

	var start_node: MapNode = view.run.graph.get_node_by_id(view.run.graph.start_id)
	var boss_node: MapNode = view.run.graph.get_node_by_id(view.run.graph.boss_id)
	var start_screen: Vector2 = view._hex_layer.camera.unproject_position(
		Vector3(view._hex_layer._hex_center(start_node).x, float(view._hex_layer._base_heights[start_node.id]), view._hex_layer._hex_center(start_node).y)
	)
	var boss_screen: Vector2 = view._hex_layer.camera.unproject_position(
		Vector3(view._hex_layer._hex_center(boss_node).x, float(view._hex_layer._base_heights[boss_node.id]), view._hex_layer._hex_center(boss_node).y)
	)
	_check(start_screen.x < boss_screen.x, "起点在屏幕左侧、Boss 在右侧")
	var pick_target: MapNode = view.run.graph.get_node_by_id(start_node.neighbor_ids[0])
	var pick_center: Vector2 = view._hex_layer._hex_center(pick_target)
	var pick_top := Vector3(pick_center.x, float(view._hex_layer._base_heights[pick_target.id]), pick_center.y)
	var pick_screen: Vector2 = view._hex_layer.camera.unproject_position(pick_top)
	_check(view._hex_layer.node_at_screen(pick_screen) == pick_target, "射线拾取命中正确的六边形")
	_check(view._board_input._node_at(pick_screen - view._board_input.get_global_rect().position) == pick_target, "覆盖层坐标换算正确")

	var path := _find_path(view.run, view.run.current_id, view.run.graph.boss_id)
	_check(path.size() > 1, "起点到 Boss 存在路径")
	for node_id in path:
		view.run.travel_to(node_id)
		await process_frame
		view._close_panel()
		await process_frame

	_check(view.run.graph.get_node_by_id(view.run.graph.boss_id).visited, "可以走到 Boss")
	_check(view.run.is_act_cleared(), "Boss 节点标记本幕完成")
	_check(view.run.get_decay_ratio() > 0.0, "探索后崩解度上升")

	var first_act: int = view.run.act_index
	view.run.advance_act()
	await process_frame
	_check(view.run.act_index == first_act + 1, "进入下一幕")
	_check(view.run.current_id == view.run.graph.start_id, "新一幕从起点开始")
	_check(view.run.get_visited_count() == 1, "新一幕只访问了起点")
	_check(is_zero_approx(view.run.get_decay_ratio()), "新一幕崩解度重置")

	view.queue_free()
	await process_frame
	_finish()


func _find_path(run: MapRun, from_id: int, to_id: int) -> Array[int]:
	var previous := {from_id: -1}
	var queue: Array[int] = [from_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == to_id:
			break
		for neighbor_id in run.graph.get_node_by_id(current).neighbor_ids:
			if previous.has(neighbor_id):
				continue
			previous[neighbor_id] = current
			queue.append(neighbor_id)
	if not previous.has(to_id):
		return []
	var path: Array[int] = []
	var cursor := to_id
	while cursor != -1:
		path.push_front(cursor)
		cursor = previous[cursor]
	return path


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok - ", message)
	else:
		_failures += 1
		printerr("  FAIL - ", message)


func _finish() -> void:
	if _failures == 0:
		print("MAP VIEW SMOKE TEST PASSED")
		quit(0)
	else:
		printerr("MAP VIEW SMOKE TEST FAILED (%d)" % _failures)
		quit(1)
