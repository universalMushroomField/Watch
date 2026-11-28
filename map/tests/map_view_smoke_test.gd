extends SceneTree
## 地图界面冒烟测试：实例化地图场景，沿路径走到 Boss，再进入下一幕。

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://ui/gui_map/map_view.tscn")
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
	_check(view.run_state != null, "单局状态已接入")
	var copy := GameText.shared()
	_check(copy.currency_name != "" and copy.currency_icon != null, "文案资源配了货币名与图标")
	_check(view._gold_label.text == copy.currency_amount_format % [copy.currency_name, view.run_state.player.gold],
		"顶栏货币按文案资源显示名称与数量")
	_check(not view._gold_label.text.contains("金币"), "顶栏不再有写死的旧货币名")
	_check(view._currency_icon.texture == copy.currency_icon and view._currency_icon.visible, "顶栏货币图标来自文案资源")
	_check(view.run.layout != null, "地图使用六边形布局")
	_check(view._hex_layer != null, "六边形层已创建")
	var board: HexLayout = view.run.layout
	var board_rect: Rect2 = view._hex_layer._available_rect(view.run_state.map_config)
	print("  实机布局 %d×%d R=%.3f span=%.3f×%.3f nodes=%d 可用矩形=%.3f×%.3f" % [
		board.columns, board.rows, board.hex_radius, board.get_world_width(), board.get_world_depth(),
		view.run.graph.get_node_count(), board_rect.size.x, board_rect.size.y])
	_check(board.get_world_width() <= board_rect.size.x + 0.001 and board.get_world_depth() <= board_rect.size.y + 0.001,
		"棋盘完整落在可用矩形内")
	_check(board.columns <= view.run_state.map_config.max_columns and board.rows <= view.run_state.map_config.max_rows,
		"棋盘不超过配置的列/行上限")
	_check(view._hex_layer.get_tile_count() == view.run.graph.get_node_count(), "每个节点都生成了六边形")
	var layer: MapHexLayer = view._hex_layer
	var model := layer.terrain as MapTerrainModel
	_check(model != null and model.source_mesh != null and model.mesh != null
		and (model.mesh != model.source_mesh) == model.voxelize_terrain,
		"地图网格与体素生成开关一致")
	var terrain_material := model.material_override as ShaderMaterial
	_check(terrain_material != null and terrain_material.next_pass != null,
		"地形保留像素化后处理")
	_check(model.is_visible_in_tree() and (model.layers & layer.camera.cull_mask) != 0,
		"地图相机能绘制白模")
	var locations_valid := true
	for node in view.run.graph.nodes:
		var location := layer.get_location(node.id)
		locations_valid = locations_valid and location != null and location.scene_file_path == layer.LOCATION_SCENES[node.type].resource_path and view.content_scenes.has(node.type)
	_check(locations_valid, "每个地点加载对应类型的独立场景及内容资源")
	var attached := true
	var planar := true
	var edges := 0
	for node in view.run.graph.nodes:
		var attachment: Node3D = layer.get_location(node.id).attachment
		var holder: Node3D = layer.get_location(node.id).interaction
		var point := attachment.global_position
		var xz := Vector2(point.x, point.z)
		attached = attached and is_equal_approx(point.y, layer._surface.height_at(xz))
		planar = planar and is_equal_approx(holder.global_position.y, layer._interaction_plane)
		edges += node.neighbor_ids.size()
	_check(attached, "附着点位于真实地表")
	_check(planar, "交互点初始共面")
	_check(layer._paths.size() * 2 == edges and layer._attachment_paths.mesh != null and layer._interaction_paths.mesh != null, "两组路径覆盖图的每条边")
	var reachable_ids := {}
	for node in view.run.get_reachable_nodes():
		reachable_ids[node.id] = true
	var colors_match := true
	var marks_match := true
	for node in view.run.graph.nodes:
		var location := layer.get_location(node.id)
		colors_match = colors_match and location.label.modulate.is_equal_approx(location.get_label_color(location.state))
		if node.id == view.run.current_id:
			marks_match = marks_match and location.highlight.visible and location.highlight.kind == MapHighlight.Kind.CURRENT
		elif node.visited:
			marks_match = marks_match and not location.highlight.visible
		elif reachable_ids.has(node.id):
			marks_match = marks_match and location.highlight.visible and location.highlight.kind == MapHighlight.Kind.REACHABLE
		else:
			marks_match = marks_match and not location.highlight.visible
	_check(colors_match, "球体和标签用同一个状态色（玩家所在节点的标签是压在红底上的近白色）")
	_check(marks_match, "只有玩家所在节点和可前往节点带标记环")
	var start_node: MapNode = view.run.graph.get_node_by_id(view.run.graph.start_id)
	var pick_target: MapNode = view.run.graph.get_node_by_id(start_node.neighbor_ids[0])
	var pick_holder: Node3D = layer.get_location(pick_target.id).interaction
	var pick_top := pick_holder.global_position
	var pick_screen: Vector2 = view._hex_layer.camera.unproject_position(pick_top)
	_check(view._hex_layer.node_at_screen(pick_screen) == pick_target, "屏幕拾取命中正确的顶点")
	_check(view._board_input._node_at(pick_screen - view._board_input.get_global_rect().position) == pick_target, "覆盖层坐标换算正确")
	layer.set_hover_id(pick_target.id)
	_check(not layer._hover_paths.is_empty() and layer._hover_plane_path.mesh != null,
		"悬停可前往节点时亮出从玩家位置走的路径")
	_check(layer.get_location(pick_target.id).highlight.kind == MapHighlight.Kind.HOVER,
		"悬停的可前往节点换成悬停环")
	layer.set_hover_id(-1)
	_check(layer._hover_paths.is_empty(), "鼠标移开后收起悬停路径")

	var camera := view._hex_layer.camera as MapCamera
	var original_position := pick_holder.global_position
	var original_marker_scale := pick_holder.scale
	var path_vertices: PackedVector3Array = layer._interaction_paths.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var original_path_width := path_vertices[0].distance_to(path_vertices[1])
	camera.orbit_drag(-20.0)
	var zoom_point := camera.unproject_position(original_position)
	camera.zoom_at(zoom_point)
	view._hex_layer._process(1.0)
	var zoomed := pick_holder.global_position
	path_vertices = layer._interaction_paths.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(pick_holder.scale.length() > original_marker_scale.length(), "放大时地点标记变大")
	_check(path_vertices[0].distance_to(path_vertices[1]) > original_path_width, "放大时连线变宽")
	_check(Vector2(zoomed.x, zoomed.z).is_equal_approx(Vector2(original_position.x, original_position.z)), "旋转和缩放后节点的世界 XZ 不变")
	var attachment: Node3D = layer.get_location(pick_target.id).attachment
	var ground := attachment.global_position.y
	_check(absf(zoomed.y - ground) < absf(original_position.y - ground), "放大时节点高度向地表过渡")
	_check(view._hex_layer.node_at_screen(camera.unproject_position(zoomed)) == pick_target, "高度变化后拾取仍对齐节点")
	var orbit_basis := camera.global_basis
	camera.reset_zoom(layer.get_map_center())
	_check(camera.unproject_position(layer.get_map_center()).distance_to(camera.get_viewport().get_visible_rect().get_center()) < 0.01, "缩放复位时底图中心回到屏幕中心")
	_check(camera.global_basis.is_equal_approx(orbit_basis), "缩放复位保留旋转角度")
	view._hex_layer._process(1.0)
	_check(pick_holder.global_position.is_equal_approx(original_position), "缩放复位后恢复节点高度")
	var path := _find_path(view.run, view.run.current_id, view.run.graph.boss_id)
	_check(path.size() > 1, "起点到 Boss 存在路径")
	var initial_gold: int = view.run_state.player.gold
	for node_id in path:
		if node_id == view.run.current_id:
			continue
		view._on_node_pressed(view.run.graph.get_node_by_id(node_id))
		await process_frame
		if view.run.get_current_node().type == MapNode.Type.BATTLE:
			var battle: BaseFight = view.run_state.fight_system
			_check(battle != null and not view.visible, "普通战斗直接进入模板")
			if battle != null:
				for enemy in battle.enemies:
					enemy.health = 0
				battle._finish_if_decided()
				await process_frame
				var settlement = view._battle_layer.get_node("Settlement")
				var reward = settlement.get_node("%Rewards").get_child(0)
				var before: int = view.run_state.player.gold
				reward.pressed.emit()
				var after: int = view.run_state.player.gold
				reward.pressed.emit()
				_check(after > before and view.run_state.player.gold == after, "奖励只结算一次")
				var rewards = settlement.get_node("%Rewards")
				var deck_size: int = view.run_state.player.get_deck_size()
				rewards.get_child(1).pressed.emit()
				_check(view.run_state.player.get_deck_size() == deck_size + 1, "奖励卡加入本局卡组")
				if rewards.get_child_count() == 3:
					rewards.get_child(2).pressed.emit()
				_check(view.run_state.player.collectibles.size() == 1, "铭牌加入本局收藏")
				settlement.get_node("%Leave").pressed.emit()
				_check(view.visible and view.run.current_id == node_id, "胜利返回原地图")
			continue
		var expected := "res://ui/gui_map/content/%s.tscn" % str(MapNode.Type.find_key(view.run.graph.get_node_by_id(node_id).type)).to_lower()
		_check(view._choices.get_child_count() > 0 and view._choices.get_child(0).scene_file_path == expected, "进入地点挂载已配置的内容场景")
		view._close_panel()
		await process_frame

	_check(view.run.graph.get_node_by_id(view.run.graph.boss_id).visited, "可以走到 Boss")
	_check(view.run_state.player.gold >= initial_gold, "结算奖励保留")
	_check(view.run.is_act_cleared(), "Boss 节点标记本幕完成")
	_check(view.run.get_decay_ratio() > 0.0, "探索后崩解度上升")
	var back: Array[int] = view.run.find_path_to(view.run.graph.start_id)
	_check(back.size() > 1 and back[0] == view.run.current_id and back[back.size() - 1] == view.run.graph.start_id,
		"已探索节点之间能算出走过的路径")
	layer.set_hover_id(view.run.graph.start_id)
	_check(not layer._hover_paths.is_empty(), "悬停已访问节点时标出走过的路径")
	layer.set_hover_id(-1)
	_check(view.run.find_path_to(view.run.current_id) == [view.run.current_id], "悬停自己时不画路径")

	var first_act: int = view.run_state.act_index
	view.run_state.advance_act()
	await process_frame
	_check(view.run_state.act_index == first_act + 1, "进入下一幕")
	_check(view.run.current_id == view.run.graph.start_id, "新一幕从起点开始")
	_check(view.run.get_visited_count() == 1, "新一幕只访问了起点")
	_check(view.run.extreme_steps > 0, "新一幕继承极端度")

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
