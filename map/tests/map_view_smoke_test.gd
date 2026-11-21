extends SceneTree
## 地图界面冒烟测试：实例化地图场景，沿路径走到 Boss，再进入下一幕。

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://map/map_view.tscn")
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
