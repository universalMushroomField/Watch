class_name MapGenerator
extends RefCounted

## 尖顶格角点。X、Z 单位分别是 sqrt(3) * 半径 / 2 和半径 / 2。
const CORNERS: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 1),
	Vector2i(-1, -1), Vector2i(0, -2), Vector2i(1, -1),
]
var config: MapConfig
var layout: HexLayout
var _rng := RandomNumberGenerator.new()


func _init(map_config: MapConfig = null, hex_layout: HexLayout = null) -> void:
	config = map_config if map_config != null else MapConfig.new()
	layout = hex_layout


## 生成一张地图。[param seed_value] 小于 0 时随机取种子。
## 必须显式传入拟合后的布局（[method HexLayout.fit]），没有默认回退值。
func generate(seed_value: int = -1) -> MapGraph:
	assert(layout != null, "MapGenerator 需要显式传入拟合后的棋盘布局。")
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var graph := MapGraph.new()
	graph.layout = layout
	var board := layout
	var target := maxi(config.node_count, 2)
	# 内部蜂巢至少有 2 * columns * rows 个角点；两端额外提供角点。
	if config.node_count > 0:
		var columns := layout.columns
		while 2 * (columns * layout.rows + columns + layout.rows) + (7 if layout.rows == 2 else 6) < target:
			columns += 1
		if columns > layout.columns:
			var radius := layout.hex_radius * (layout.columns + 2.5) / (columns + 2.5)
			board = HexLayout.new(columns, layout.rows, radius)
			graph.layout = board

	var vertices := {}
	var edges: Array[Vector2i] = []
	var seen_edges := {}
	for column in range(board.get_total_columns()):
		for row in range(board.rows):
			if (column == 0 or column == board.get_total_columns() - 1) and row != board.get_middle_row():
				continue
			var center := Vector2i(2 * column + (row & 1), 3 * row)
			var ids: Array[int] = []
			for corner in CORNERS:
				var key := center + corner
				if not vertices.has(key):
					var node := graph.add_node(MapNode.Type.BATTLE, key.x, key.y)
					node.vertex = key
					vertices[key] = node.id
				ids.append(vertices[key])
			for i in range(6):
				var a := ids[i]
				var b := ids[(i + 1) % 6]
				var edge := Vector2i(mini(a, b), maxi(a, b))
				if not seen_edges.has(edge):
					seen_edges[edge] = true
					edges.append(edge)

	if config.node_count > 0 and target < graph.nodes.size():
		graph = _take_connected_nodes(graph, edges, target)

	var left: Array[MapNode] = []
	var right: Array[MapNode] = []
	var min_x := graph.nodes[0].vertex.x
	var max_x := min_x
	for node in graph.nodes:
		min_x = mini(min_x, node.vertex.x)
		max_x = maxi(max_x, node.vertex.x)
	for node in graph.nodes:
		if node.vertex.x == min_x:
			left.append(node)
		if node.vertex.x == max_x:
			right.append(node)
	var start := left[_rng.randi_range(0, left.size() - 1)]
	var boss := right[_rng.randi_range(0, right.size() - 1)]
	if start == boss:
		boss = right[(right.find(start) + 1) % right.size()]
	start.type = MapNode.Type.START
	boss.type = MapNode.Type.BOSS
	graph.start_id = start.id
	graph.boss_id = boss.id
	_connect_network(graph, edges)
	_assign_types(graph)
	return graph


## 从左端沿相邻边扩展。每个新地点都有一个已入选的邻居。
func _take_connected_nodes(source: MapGraph, edges: Array[Vector2i], count: int) -> MapGraph:
	var neighbors := {}
	var first := source.nodes[0]
	for node in source.nodes:
		neighbors[node.id] = []
		if node.vertex.x < first.vertex.x:
			first = node
	for edge in edges:
		neighbors[edge.x].append(edge.y)
		neighbors[edge.y].append(edge.x)
	var result := MapGraph.new()
	result.layout = source.layout
	var pending: Array[int] = [first.id]
	var queued := {first.id: true}
	var ids := {}
	for index in range(count):
		var node := source.nodes[pending[index]]
		var copy := result.add_node(node.type, node.column, node.row)
		copy.vertex = node.vertex
		ids[node.id] = copy.id
		var adjacent: Array = neighbors[node.id]
		_shuffle(adjacent)
		for neighbor in adjacent:
			if not queued.has(neighbor):
				queued[neighbor] = true
				pending.append(neighbor)
	var retained: Array[Vector2i] = []
	for edge in edges:
		if ids.has(edge.x) and ids.has(edge.y):
			retained.append(Vector2i(ids[edge.x], ids[edge.y]))
	edges.assign(retained)
	return result


## 随机生成树保证全图连通，再补回部分边形成可选路线。
func _connect_network(graph: MapGraph, edges: Array[Vector2i]) -> void:
	_shuffle(edges)
	var parents: Array[int] = []
	for node in graph.nodes:
		parents.append(node.id)
	for edge in edges:
		var a := _root(parents, edge.x)
		var b := _root(parents, edge.y)
		if a != b:
			parents[b] = a
			graph.link(edge.x, edge.y)
		elif _rng.randf() < 0.28:
			graph.link(edge.x, edge.y)


func _root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		index = parents[index]
	return index

## 随机分配精英、商店、休息、宝箱、事件和普通战斗。
func _assign_types(graph: MapGraph) -> void:
	var pool: Array[MapNode] = []
	for node in graph.nodes:
		if node.type == MapNode.Type.START or node.type == MapNode.Type.BOSS:
			continue
		pool.append(node)
	_shuffle(pool)

	pool = _assign_type(pool, MapNode.Type.HUB, config.hub_count)
	pool = _assign_type(pool, MapNode.Type.SHOP, config.shop_count)
	pool = _assign_type(pool, MapNode.Type.REST, config.rest_count)
	pool = _assign_type(pool, MapNode.Type.TREASURE, config.treasure_count)
	pool = _assign_elites(pool, config.elite_count)

	for node in pool:
		if _rng.randf() < config.event_ratio:
			node.type = MapNode.Type.EVENT
		else:
			node.type = MapNode.Type.BATTLE


## 从池中取出若干节点设为指定类型，返回剩下的节点。
func _assign_type(pool: Array[MapNode], node_type: MapNode.Type, count: int) -> Array[MapNode]:
	var remaining: Array[MapNode] = []
	var assigned := 0
	for node in pool:
		if assigned < count:
			node.type = node_type
			assigned += 1
		else:
			remaining.append(node)
	return remaining


## 精英只放在离起点至少两列的位置，避免开局就撞上。
func _assign_elites(pool: Array[MapNode], count: int) -> Array[MapNode]:
	var remaining: Array[MapNode] = []
	var assigned := 0
	for node in pool:
		if assigned < count and node.column >= 2:
			node.type = MapNode.Type.ELITE
			assigned += 1
		else:
			remaining.append(node)
	return remaining


func _shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temp
