extends SceneTree

## 临时冒烟测试：验证六边形地图生成、移动、崩解度与事件结算。


func _init() -> void:
	var failures: Array[String] = []
	var config := MapConfig.new()
	var signatures := {}

	for seed_value in range(1, 201):
		var session := RunState.new()
		session.run_seed = seed_value
		session.map_config = config
		var run := session.create_map(HexLayout.from_config(config))
		session.queue_free()
		var graph := run.graph
		var label := "seed %d: " % seed_value

		if graph.start_id < 0 or graph.boss_id < 0:
			failures.append(label + "缺少起点或 Boss")
			continue
		if not graph.is_fully_connected():
			failures.append(label + "存在不可达节点")
		if graph.layout == null:
			failures.append(label + "缺少六边形布局")
			continue

		_check_layout(graph, label, failures)

		for node in graph.nodes:
			for neighbor_id in node.neighbor_ids:
				var neighbor := graph.get_node_by_id(neighbor_id)
				if neighbor_id == node.id:
					failures.append(label + "出现自环")
				elif neighbor == null or not neighbor.neighbor_ids.has(node.id):
					failures.append(label + "连边不对称")

		if run.get_visited_count() != 1 or run.get_decay_visited_count() != 0:
			failures.append(label + "初始访问数异常")
		if not is_zero_approx(run.get_decay_ratio()):
			failures.append(label + "起点计入了崩解度")
		if run.get_decay_total_count() != graph.get_node_count() - 1:
			failures.append(label + "崩解度总数未排除起点")

		var path := _find_path(graph, graph.start_id, graph.boss_id)
		if path.is_empty():
			failures.append(label + "起点到 Boss 无路径")
			continue

		if not run.travel_to(path[1]):
			failures.append(label + "无法移动到第二个节点")
			continue

		# 已探索的节点不能再次进入。
		if run.can_travel_to(graph.start_id) or run.travel_to(graph.start_id):
			failures.append(label + "允许回到已探索节点")
		if run.current_id != path[1]:
			failures.append(label + "拒绝移动后位置被改变")
		if not _reachable_matches(run):
			failures.append(label + "可前往集合与已探索节点的邻居不一致")

		for index in range(2, path.size()):
			if not run.travel_to(path[index]):
				failures.append(label + "路径移动失败于第 %d 步" % index)
				break
			if not _reachable_matches(run):
				failures.append(label + "第 %d 步后可前往集合不正确" % index)
		if not run.is_act_cleared():
			failures.append(label + "到达 Boss 后未判定本幕结束")
		if run.get_visited_count() != path.size():
			failures.append(label + "访问数 %d 与路径长度 %d 不符" % [run.get_visited_count(), path.size()])
		if run.get_decay_visited_count() != path.size() - 1:
			failures.append(label + "崩解度访问数未排除起点")
		if not is_equal_approx(run.get_decay_ratio(), float(path.size() - 1) / float(graph.get_node_count() - 1)):
			failures.append(label + "崩解度计算不符")
		if run.can_travel_to(graph.start_id):
			failures.append(label + "本幕结束后仍可移动")

		var old_graph := graph
		session.advance_act()
		if session.act_index != 1:
			failures.append(label + "进入下一幕失败")
		if run.graph == old_graph or run.get_visited_count() != 1 or not is_zero_approx(run.get_decay_ratio()):
			failures.append(label + "下一幕未重置")

		var signature := _signature(run.graph)
		if signatures.has(signature):
			failures.append(label + "不同种子生成了相同地图")
		signatures[signature] = true

	var player := RunPlayerState.new(50, 10)
	var choice := MapEventChoice.new()
	choice.gold_delta = 15
	choice.health_delta = -5
	choice.apply(player)
	if player.gold != 25 or player.health != 45:
		failures.append("事件结算错误：gold=%d health=%d" % [player.gold, player.health])

	var deck := CardDeck.new()
	deck.turn_draw_count = 5
	deck.cards.append(CardData.new())
	var state := RunPlayerState.new(40, 0, deck)
	if state.deck == deck or state.get_deck_size() != 1 or state.deck.turn_draw_count != 5:
		failures.append("卡组复制失败")

	if failures.is_empty():
		print("MAP SMOKE TEST PASSED (200 seeds)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		printerr("FAILURES: %d" % failures.size())
		quit(1)


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
func _check_layout(graph: MapGraph, label: String, failures: Array[String]) -> void:
	var start := graph.get_node_by_id(graph.start_id)
	var boss := graph.get_node_by_id(graph.boss_id)
	if start == null or start.type != MapNode.Type.START or boss == null or boss.type != MapNode.Type.BOSS:
		failures.append(label + "缺少起点或 Boss")
		return
	var vertices := {}
	for node in graph.nodes:
		if vertices.has(node.vertex):
			failures.append(label + "出现重复顶点")
		vertices[node.vertex] = true
		if node.neighbor_ids.size() > 3:
			failures.append(label + "顶点超过三条蜂巢边")
		for id in node.neighbor_ids:
			var neighbor := graph.get_node_by_id(id)
			var delta := neighbor.vertex - node.vertex
			if 3 * delta.x * delta.x + delta.y * delta.y != 4 or not neighbor.neighbor_ids.has(node.id):
				failures.append(label + "存在无效蜂巢边")
	if graph.collect_reachable_ids(start.id).size() != graph.get_node_count():
		failures.append(label + "网络未完全连通")
