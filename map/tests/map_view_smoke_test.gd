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
	var layer: MapHexLayer = view._hex_layer
	var attached := true
	var planar := true
	var edges := 0
	for node in view.run.graph.nodes:
		var attachment: Node3D = layer._tiles[node.id]["attachment"]
		var holder: Node3D = layer._tiles[node.id]["holder"]
		var point := attachment.global_position
		var xz := Vector2(point.x, point.z)
		attached = attached and is_equal_approx(point.y, layer._surface.height_at(xz))
		planar = planar and is_equal_approx(holder.global_position.y, layer._interaction_plane)
		edges += node.neighbor_ids.size()
	_check(attached, "附着点位于真实地表")
	_check(planar, "交互点初始共面")
	_check(layer._paths.size() * 2 == edges and layer._attachment_paths.mesh != null and layer._interaction_paths.mesh != null, "两组路径覆盖图的每条边")
	var start_node: MapNode = view.run.graph.get_node_by_id(view.run.graph.start_id)
	var pick_target: MapNode = view.run.graph.get_node_by_id(start_node.neighbor_ids[0])
	var pick_holder: Node3D = view._hex_layer._tiles[pick_target.id]["holder"]
	var pick_top := pick_holder.global_position
	var pick_screen: Vector2 = view._hex_layer.camera.unproject_position(pick_top)
	_check(view._hex_layer.node_at_screen(pick_screen) == pick_target, "屏幕拾取命中正确的顶点")
	_check(view._board_input._node_at(pick_screen - view._board_input.get_global_rect().position) == pick_target, "覆盖层坐标换算正确")

	var camera := view._hex_layer.camera as MapCamera
	var original_position := pick_holder.global_position
	camera.orbit_drag(-20.0)
	var zoom_point := camera.unproject_position(original_position)
	camera.zoom_at(zoom_point)
	view._hex_layer._process(1.0)
	var zoomed := pick_holder.global_position
	_check(Vector2(zoomed.x, zoomed.z).is_equal_approx(Vector2(original_position.x, original_position.z)), "旋转和缩放后节点的世界 XZ 不变")
	var attachment: Node3D = layer._tiles[pick_target.id]["attachment"]
	var ground := attachment.global_position.y
	_check(absf(zoomed.y - ground) < absf(original_position.y - ground), "放大时节点高度向地表过渡")
	_check(view._hex_layer.node_at_screen(camera.unproject_position(zoomed)) == pick_target, "高度变化后拾取仍对齐节点")
	camera.reset_zoom()
	view._hex_layer._process(1.0)
	_check(pick_holder.global_position.is_equal_approx(original_position), "缩放复位后恢复节点高度")
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
