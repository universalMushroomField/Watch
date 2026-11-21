extends SceneTree

## 临时冒烟测试：验证地图生成、移动、崩解度与事件结算。


func _init() -> void:
	var failures: Array[String] = []
	var config := MapConfig.new()
	var signatures := {}

	for seed_value in range(200):
		var run := MapRun.new(config, MapPlayerState.new(70, 50), seed_value)
		var graph := run.graph
		var label := "seed %d: " % seed_value

		if graph.start_id < 0 or graph.boss_id < 0:
			failures.append(label + "缺少起点或 Boss")
			continue
		if not graph.is_fully_connected():
			failures.append(label + "存在不可达节点 %s" % [graph.find_unreachable_ids()])

		_check_layout(graph, label, failures)

		for node in graph.nodes:
			for neighbor_id in node.neighbor_ids:
				var neighbor := graph.get_node_by_id(neighbor_id)
				if neighbor_id == node.id:
					failures.append(label + "出现自环")
				elif neighbor == null or not neighbor.neighbor_ids.has(node.id):
					failures.append(label + "连边不对称")
			if node.type == MapNode.Type.SHOP and (node.id == graph.start_id or node.id == graph.boss_id):
				failures.append(label + "商店占用了起点或 Boss")

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
		run.advance_act()
		if run.act_index != 1:
			failures.append(label + "进入下一幕失败")
		if run.graph == old_graph or run.get_visited_count() != 1 or not is_zero_approx(run.get_decay_ratio()):
			failures.append(label + "下一幕未重置")

		var signature := _signature(run.graph)
		if signatures.has(signature):
			failures.append(label + "不同种子生成了相同地图")
		signatures[signature] = true

	var player := MapPlayerState.new(50, 10)
	var choice := MapEventChoice.new()
	choice.gold_delta = 15
	choice.health_delta = -5
	choice.apply(player)
	if player.gold != 25 or player.health != 45:
		failures.append("事件结算错误：gold=%d health=%d" % [player.gold, player.health])

	var deck := CardDeck.new()
	deck.turn_draw_count = 5
	deck.cards.append(CardData.new())
	var state := MapPlayerState.new(40, 0, deck)
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
		parts.append("%d:%d:%s:%s" % [node.id, node.type, node.position, node.neighbor_ids])
	return "|".join(parts)


## 检查放射布局的结构约束：Boss 居中、每个节点只有一个内层父节点、环边只连相邻角度。
func _check_layout(graph: MapGraph, label: String, failures: Array[String]) -> void:
	var band_count := graph.get_band_count()
	if band_count < 3:
		failures.append(label + "层数异常")
		return

	var boss := graph.get_node_by_id(graph.boss_id)
	if boss == null or not boss.position.is_equal_approx(Vector2(0.5, 0.5)):
		failures.append(label + "Boss 不在中心")

	var start := graph.get_node_by_id(graph.start_id)
	if start != null and start.neighbor_ids.size() != 1:
		failures.append(label + "起点度数不是 1")

	for node in graph.nodes:
		if node.id == graph.boss_id:
			continue
		var inward := 0
		for neighbor_id in node.neighbor_ids:
			var neighbor := graph.get_node_by_id(neighbor_id)
			if neighbor != null and neighbor.band == node.band + 1:
				inward += 1
		if inward != 1:
			failures.append(label + "节点 %d 的内层父节点数为 %d" % [node.id, inward])
		var expected_radius := 0.5 * float(band_count - 1 - node.band) / float(band_count - 1)
		var actual_radius := node.position.distance_to(Vector2(0.5, 0.5))
		if absf(actual_radius - expected_radius) > 0.0001:
			failures.append(label + "节点 %d 的环半径异常" % node.id)

	var inner_band_count := 0
	for node in graph.nodes:
		if node.band == band_count - 2:
			inner_band_count += 1
	if boss != null and boss.neighbor_ids.size() != inner_band_count:
		failures.append(label + "Boss 没有连到所有内层节点")

	# 环边只能连接同层角度相邻的节点。
	for band in range(1, band_count - 1):
		var ring: Array[MapNode] = []
		for node in graph.nodes:
			if node.band == band:
				ring.append(node)
		ring.sort_custom(func(a: MapNode, b: MapNode) -> bool:
			return _node_angle(a) < _node_angle(b))
		var index_of := {}
		for index in range(ring.size()):
			index_of[ring[index].id] = index
			if index > 0 and absf(_node_angle(ring[index]) - _node_angle(ring[index - 1])) < 0.0001:
				failures.append(label + "同层节点角度重复")
		for node in ring:
			for neighbor_id in node.neighbor_ids:
				var neighbor := graph.get_node_by_id(neighbor_id)
				if neighbor == null or neighbor.band != band or not graph.is_ring_link(node.id, neighbor_id):
					continue
				var index_gap := absi(index_of[node.id] - index_of[neighbor_id])
				if index_gap != 1 and index_gap != ring.size() - 1:
					failures.append(label + "环边跳过了相邻节点")

	# 树边必须是直线，且除共享端点外不能相交。
	var tree_edges: Array = []
	for node in graph.nodes:
		for neighbor_id in node.neighbor_ids:
			if neighbor_id < node.id or graph.is_ring_link(node.id, neighbor_id):
				continue
			var neighbor := graph.get_node_by_id(neighbor_id)
			if neighbor == null:
				continue
			if absi(neighbor.band - node.band) != 1:
				failures.append(label + "树边跨了多层")
			tree_edges.append([node.id, neighbor_id, node.position, neighbor.position])
	for i in range(tree_edges.size()):
		for j in range(i + 1, tree_edges.size()):
			var edge_a: Array = tree_edges[i]
			var edge_b: Array = tree_edges[j]
			if edge_a[0] == edge_b[0] or edge_a[0] == edge_b[1] or edge_a[1] == edge_b[0] or edge_a[1] == edge_b[1]:
				continue
			if _segments_intersect(edge_a[2], edge_a[3], edge_b[2], edge_b[3]):
				failures.append(label + "树边交叉")


func _node_angle(node: MapNode) -> float:
	return atan2(node.position.y - 0.5, node.position.x - 0.5)


func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1 := _cross(c, d, a)
	var d2 := _cross(c, d, b)
	var d3 := _cross(a, b, c)
	var d4 := _cross(a, b, d)
	return ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) \
		and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0))


func _cross(origin: Vector2, target: Vector2, point: Vector2) -> float:
	return (target.x - origin.x) * (point.y - origin.y) - (target.y - origin.y) * (point.x - origin.x)
