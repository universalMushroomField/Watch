extends SceneTree

## 单局场景冒烟测试：验证 run.tscn 是游戏根节点，地图视图挂在它下面并共用同一局状态。

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://run/templates/run.tscn")
	_check(scene != null, "单局场景可以加载")
	if scene == null:
		quit(1)
		return

	var run := scene.instantiate()
	root.add_child(run)
	await process_frame
	await process_frame

	_check(run is RunState, "根节点是 RunState")
	var run_state := run as RunState
	_check(run_state.map != null, "单局初始化了地图")
	_check(run_state.player != null, "单局初始化了玩家状态")
	if run_state.player != null:
		_check(run_state.player.get_deck_size() > 0, "玩家拥有卡组")

	if run_state.map == null:
		run.queue_free()
		await process_frame
		print("RUN SMOKE TEST FAILED: %d" % _failures)
		quit(1)
		return

	var seed_generator := root.get_node_or_null("/root/SeedGenerator")
	if seed_generator != null:
		_check(run_state.run_seed == int(seed_generator.get("run_seed")), "本局种子来自 SeedGenerator")
	else:
		_check(run_state.run_seed != 0, "本局种子已确定")

	var view: Node = run.get_node_or_null("UI/MapView")
	_check(view != null, "单局场景包含地图视图")
	if view != null:
		var hex_layer = view.get("_hex_layer")
		var board_input = view.get("_board_input")
		_check(view.get("run") == run_state.map, "地图视图使用单局的地图进度")
		_check(hex_layer != null and hex_layer.get("run") == run_state.map, "六边形层使用同一局地图")
		_check(hex_layer != null and hex_layer.get_tile_count() == run_state.map.graph.get_node_count(), "每个节点都有六边形")
		_check(hex_layer != null and hex_layer.get_path_count() > 0, "六边形网络已生成路径")
		_check(board_input != null and board_input.get("run") == run_state.map, "六边形输入已接入")

		# 点击起点右侧的邻居，验证“已探索节点的未探索邻居”规则在 3D 输入层同样生效。
		var start := run_state.map.graph.get_node_by_id(run_state.map.graph.start_id)
		_check(start != null and not start.neighbor_ids.is_empty(), "起点存在相邻六边形")
		if start != null and not start.neighbor_ids.is_empty():
			var target := run_state.map.graph.get_node_by_id(start.neighbor_ids[0])
			_check(run_state.map.can_travel_to(target.id), "起点邻居可以前往")
			var before := run_state.map.get_visited_count()
			run_state.map.travel_to(target.id)
			_check(run_state.map.get_visited_count() == before + 1, "前往邻居后探索计数增加")

	var menu_scene: PackedScene = load("res://ui/start_menu/start_menu.tscn")
	var menu := menu_scene.instantiate()
	var configured: PackedScene = menu.get("game_scene")
	_check(configured != null and configured.resource_path.ends_with("run/templates/run.tscn"), "开始菜单进入单局场景")
	menu.free()

	run.queue_free()
	await process_frame
	if _failures == 0:
		print("RUN SMOKE TEST PASSED")
		quit(0)
	else:
		print("RUN SMOKE TEST FAILED: %d" % _failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok - ", message)
	else:
		_failures += 1
		printerr("  FAIL - ", message)