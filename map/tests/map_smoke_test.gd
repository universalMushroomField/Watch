extends SceneTree

## 冒烟测试：验证六边形地图生成、移动、崩解度与事件结算。
##
## 生成相关的检查参数化跑两组布局：
## - 实机尺寸：用 map_view 实测的可用矩形和真实的 map_config.tres 走 [method HexLayout.fit]，
##   就是玩家真正看到的那套（当前 2×2 / 23 个顶点）；
## - 压力尺寸：[MapConfig] 默认上限 4×4 / 54 个顶点，只用于验证生成器在更大图上的
##   不变量，这一组不当作实机布局（实测矩形装不下它）。

## 实机可用矩形（Godot 4.7.2 headless 下 map_view 的 _available_rect() 实测值）。
const DEVICE_RECT := Rect2(Vector2(-39.40317, -20.34126), Vector2(36.14, 50.2))
## 实机顶点数，应与运行入口打印的数值对照；改地形或 map_config.tres 后同步这里。
const DEVICE_NODE_COUNT := 32
const GAME_CONFIG: MapConfig = preload("res://map/res/data/map_config.tres")

var _failures: Array[String] = []


func _init() -> void:
	var fitted := HexLayout.fit(DEVICE_RECT, GAME_CONFIG)
	_check_fit(fitted, DEVICE_RECT, GAME_CONFIG, "实机拟合布局")
	_check_fit_variants(GAME_CONFIG)
	_check_ceiling(GAME_CONFIG)
	_run_generation_suite("实机拟合 %d×%d" % [fitted.columns, fitted.rows], fitted, GAME_CONFIG, DEVICE_NODE_COUNT)
	var stress := MapConfig.new()
	_run_generation_suite("压力上限 %d×%d" % [stress.max_columns, stress.max_rows],
		HexLayout.new(stress.max_columns, stress.max_rows, stress.hex_radius), stress, -1)
	_check_settlement()

	if _failures.is_empty():
		print("MAP SMOKE TEST PASSED (200 seeds × 2 layouts)")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		printerr("FAILURES: %d" % _failures.size())
		quit(1)


## 一组布局跑 200 个种子：起点/Boss、连通性、蜂巢边、崩解度、移动与换幕。
func _run_generation_suite(name: String, layout: HexLayout, config: MapConfig, expected_nodes: int) -> void:
	var signatures := {}
	print("layout %s: %d×%d R=%.3f span=%.3f×%.3f" % [
		name, layout.columns, layout.rows, layout.hex_radius,
		layout.get_world_width(), layout.get_world_depth()])

	for seed_value in range(1, 201):
		var session := RunState.new()
		session.run_seed = seed_value
		session.map_config = config
		var run := session.create_map(layout)
		session.queue_free()
		var graph := run.graph
		var label := "%s / seed %d: " % [name, seed_value]

		if graph.start_id < 0 or graph.boss_id < 0:
			_failures.append(label + "缺少起点或 Boss")
			continue
		if not graph.is_fully_connected():
			_failures.append(label + "存在不可达节点")
		if graph.layout == null or graph.layout != layout:
			_failures.append(label + "地图没有使用传入的布局")
			continue
		if expected_nodes > 0 and graph.get_node_count() != expected_nodes:
			_failures.append(label + "节点数 %d 与实机 %d 不符" % [graph.get_node_count(), expected_nodes])

		_check_layout(graph, label)

		for node in graph.nodes:
			for neighbor_id in node.neighbor_ids:
				var neighbor := graph.get_node_by_id(neighbor_id)
				if neighbor_id == node.id:
					_failures.append(label + "出现自环")
				elif neighbor == null or not neighbor.neighbor_ids.has(node.id):
					_failures.append(label + "连边不对称")

		if run.get_visited_count() != 1 or run.get_decay_visited_count() != 0:
			_failures.append(label + "初始访问数异常")
		if not is_zero_approx(run.get_decay_ratio()):
			_failures.append(label + "起点计入了崩解度")
		if run.get_decay_total_count() != graph.get_node_count() - 1:
			_failures.append(label + "崩解度总数未排除起点")

		var path := _find_path(graph, graph.start_id, graph.boss_id)
		if path.is_empty():
			_failures.append(label + "起点到 Boss 无路径")
			continue

		if not run.travel_to(path[1]):
			_failures.append(label + "无法移动到第二个节点")
			continue

		# 已探索的节点不能再次进入。
		if run.can_travel_to(graph.start_id) or run.travel_to(graph.start_id):
			_failures.append(label + "允许回到已探索节点")
		if run.current_id != path[1]:
			_failures.append(label + "拒绝移动后位置被改变")
		if not _reachable_matches(run):
			_failures.append(label + "可前往集合与已探索节点的邻居不一致")

		for index in range(2, path.size()):
			if not run.travel_to(path[index]):
				_failures.append(label + "路径移动失败于第 %d 步" % index)
				break
			if not _reachable_matches(run):
				_failures.append(label + "第 %d 步后可前往集合不正确" % index)
		if not run.is_act_cleared():
			_failures.append(label + "到达 Boss 后未判定本幕结束")
		if run.get_visited_count() != path.size():
			_failures.append(label + "访问数 %d 与路径长度 %d 不符" % [run.get_visited_count(), path.size()])
		if run.get_decay_visited_count() != path.size() - 1:
			_failures.append(label + "崩解度访问数未排除起点")
		if not is_equal_approx(run.get_decay_ratio(), float(path.size() - 1) / 64.0):
			_failures.append(label + "崩解度计算不符")
		if run.can_travel_to(graph.start_id):
			_failures.append(label + "本幕结束后仍可移动")

		var old_graph := graph
		session.advance_act()
		if session.act_index != 1:
			_failures.append(label + "进入下一幕失败")
		if run.graph == old_graph or run.get_visited_count() != 1 or run.extreme_steps != path.size() - 1:
			_failures.append(label + "下一幕未重置")

		var signature := _signature(run.graph)
		if signatures.has(signature):
			_failures.append(label + "不同种子生成了相同地图")
		signatures[signature] = true


## 事件结算、卡组复制，以及缺少布局时拒绝创建地图。
func _check_settlement() -> void:
	var player := RunPlayerState.new(50, 10)
	var choice := MapEventChoice.new()
	choice.gold_delta = 15
	choice.health_delta = -5
	choice.apply(player)
	if player.gold != 25 or player.health != 45:
		_failures.append("事件结算错误：gold=%d health=%d" % [player.gold, player.health])

	var deck := CardDeck.new()
	deck.turn_draw_count = 5
	deck.cards.append(CardData.new())
	var state := RunPlayerState.new(40, 0, deck)
	if state.deck == deck or state.get_deck_size() != 1 or state.deck.turn_draw_count != 5:
		_failures.append("卡组复制失败")

	var session := RunState.new()
	session.run_seed = 1
	print("（下面这条 ERROR 来自 create_map(null) 的守卫，属预期）")
	var no_layout := session.create_map(null)
	session.queue_free()
	if no_layout != null:
		_failures.append("缺少布局时仍创建了地图")


## 拟合出的布局必须完整落在可用矩形内，且不超过配置上限。
func _check_fit(layout: HexLayout, rect: Rect2, config: MapConfig, label: String) -> void:
	if layout.get_world_width() > rect.size.x + 0.001:
		_failures.append("%s 超出矩形宽度：%.3f > %.3f" % [label, layout.get_world_width(), rect.size.x])
	if layout.get_world_depth() > rect.size.y + 0.001:
		_failures.append("%s 超出矩形深度：%.3f > %.3f" % [label, layout.get_world_depth(), rect.size.y])
	if layout.columns > config.max_columns or layout.rows > config.max_rows:
		_failures.append("%s 超过配置上限：%d×%d" % [label, layout.columns, layout.rows])
	if layout.hex_radius > config.hex_radius + 0.001:
		_failures.append("%s 半径超过目标值：%.3f" % [label, layout.hex_radius])


## 扫一遍不同大小的可用矩形，拟合结果一律不得越界。
func _check_fit_variants(config: MapConfig) -> void:
	for width in range(8, 81, 4):
		for height in range(8, 81, 4):
			var rect := Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height))
			var layout := HexLayout.fit(rect, config)
			_check_fit(layout, rect, config, "矩形 %d×%d 的拟合布局" % [width, height])
			if layout.columns < 2 or layout.rows < 2:
				_failures.append("矩形 %d×%d 的拟合布局小于最小尺寸" % [width, height])


## 宽裕矩形下拟合结果正好是配置上限：上限是封顶值，而不是拟合目标。
func _check_ceiling(config: MapConfig) -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(60.0, 40.0))
	var layout := HexLayout.fit(rect, config)
	_check_fit(layout, rect, config, "宽裕矩形拟合布局")
	if layout.columns != config.max_columns or layout.rows != config.max_rows:
		_failures.append("宽裕矩形下拟合没有达到配置上限：%d×%d" % [layout.columns, layout.rows])


func _find_path(graph: MapGraph, from_id: int, to_id: int) -> Array[int]:
	var came_from := {from_id: from_id}
	var queue: Array[int] = [from_id]
	while not queue.is_empty():
		var node_id: int = queue.pop_front()
		if node_id == to_id:
			var path: Array[int] = [to_id]
			while path[0] != from_id:
				path.push_front(came_from[path[0]])
			return path
		for neighbor_id in graph.get_node_by_id(node_id).neighbor_ids:
			if not came_from.has(neighbor_id):
				came_from[neighbor_id] = node_id
				queue.append(neighbor_id)
	return []


## 可前往集合应等于所有已探索节点的未探索邻居。
func _reachable_matches(run: MapRun) -> bool:
	if run.is_act_cleared():
		return run.get_reachable_nodes().is_empty()
	var expected := {}
	for node in run.graph.nodes:
		if not node.visited:
			continue
		for neighbor_id in node.neighbor_ids:
			var neighbor := run.graph.get_node_by_id(neighbor_id)
			if neighbor != null and not neighbor.visited:
				expected[neighbor_id] = true
	var actual := {}
	for node in run.get_reachable_nodes():
		actual[node.id] = true
	if expected.size() != actual.size():
		return false
	for node_id in expected:
		if not actual.has(node_id):
			return false
	return true


func _signature(graph: MapGraph) -> String:
	var parts: Array[String] = []
	for node in graph.nodes:
		parts.append("%d:%d:%d:%d:%s" % [node.id, node.type, node.column, node.row, node.neighbor_ids])
	return "|".join(parts)


## 检查唯一蜂巢顶点、合法边和全图连通。
func _check_layout(graph: MapGraph, label: String) -> void:
	var start := graph.get_node_by_id(graph.start_id)
	var boss := graph.get_node_by_id(graph.boss_id)
	if start == null or start.type != MapNode.Type.START or boss == null or boss.type != MapNode.Type.BOSS:
		_failures.append(label + "缺少起点或 Boss")
		return
	var vertices := {}
	for node in graph.nodes:
		if vertices.has(node.vertex):
			_failures.append(label + "出现重复顶点")
		vertices[node.vertex] = true
		if node.neighbor_ids.size() > 3:
			_failures.append(label + "顶点超过三条蜂巢边")
		for id in node.neighbor_ids:
			var neighbor := graph.get_node_by_id(id)
			var delta := neighbor.vertex - node.vertex
			if 3 * delta.x * delta.x + delta.y * delta.y != 4 or not neighbor.neighbor_ids.has(node.id):
				_failures.append(label + "存在无效蜂巢边")
	if graph.collect_reachable_ids(start.id).size() != graph.get_node_count():
		_failures.append(label + "网络未完全连通")
