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

		for node in graph.nodes:
			for neighbor_id in node.neighbor_ids:
				var neighbor := graph.get_node_by_id(neighbor_id)
				if neighbor_id == node.id:
					failures.append(label + "出现自环")
				elif neighbor == null or not neighbor.neighbor_ids.has(node.id):
					failures.append(label + "连边不对称")
			if node.type == MapNode.Type.SHOP and (node.id == graph.start_id or node.id == graph.boss_id):
				failures.append(label + "商店占用了起点或 Boss")

		if run.get_visited_count() != 1:
			failures.append(label + "初始访问数不是 1")
		if run.get_decay_ratio() <= 0.0 or run.get_decay_ratio() > 1.0:
			failures.append(label + "初始崩解度异常")

		var path := _find_path(graph, graph.start_id, graph.boss_id)
		if path.is_empty():
			failures.append(label + "起点到 Boss 无路径")
			continue

		if not run.travel_to(path[1]):
			failures.append(label + "无法移动到第二个节点")
			continue

		# 回到已探索的起点不应提高崩解度。
		var visited_before := run.get_visited_count()
		if not run.travel_to(graph.start_id):
			failures.append(label + "无法回头")
		if run.get_visited_count() != visited_before:
			failures.append(label + "回头也提高了崩解度")

		for index in range(1, path.size()):
			if not run.travel_to(path[index]):
				failures.append(label + "路径移动失败于第 %d 步" % index)
				break
		if not run.is_act_cleared():
			failures.append(label + "到达 Boss 后未判定本幕结束")
		if run.get_visited_count() != path.size():
			failures.append(label + "访问数 %d 与路径长度 %d 不符" % [run.get_visited_count(), path.size()])
		if not is_equal_approx(run.get_decay_ratio(), float(path.size()) / float(graph.get_node_count())):
			failures.append(label + "崩解度计算不符")
		if run.can_travel_to(graph.start_id):
			failures.append(label + "本幕结束后仍可移动")

		var old_graph := graph
		run.advance_act()
		if run.act_index != 1:
			failures.append(label + "进入下一幕失败")
		if run.graph == old_graph or run.get_visited_count() != 1:
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


func _signature(graph: MapGraph) -> String:
	var parts: Array[String] = []
	for node in graph.nodes:
		parts.append("%d:%d:%s:%s" % [node.id, node.type, node.position, node.neighbor_ids])
	return "|".join(parts)
