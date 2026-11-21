## 生成自由网状地图：分层摆放节点，再按距离连边并修补连通性。
class_name MapGenerator
extends RefCounted

## 生成参数。
var config: MapConfig
var _rng := RandomNumberGenerator.new()


func _init(map_config: MapConfig = null) -> void:
	config = map_config if map_config != null else MapConfig.new()


## 生成一张完整地图。seed_value 为负数时使用随机种子。
func generate(seed_value: int = -1) -> MapGraph:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var band_count := maxi(config.band_count, 3)
	var graph := MapGraph.new()
	var bands: Array[Array] = []

	var start := graph.add_node(MapNode.Type.START, 0, Vector2(0.5, 0.0))
	bands.append([start])
	for band in range(1, band_count - 1):
		bands.append(_create_band(graph, band, band_count))
	var boss := graph.add_node(MapNode.Type.BOSS, band_count - 1, Vector2(0.5, 1.0))
	bands.append([boss])

	for band in range(0, band_count - 1):
		for node: MapNode in bands[band]:
			for target in _nearest_nodes(bands[band + 1], node.position, config.links_per_node):
				graph.link(node.id, target.id)

	_ensure_inbound_links(graph, bands)
	_add_skip_links(graph, bands)
	_add_extra_links(graph)
	_repair_connectivity(graph)
	_assign_types(graph)
	return graph


## 在指定层随机摆放节点。
func _create_band(graph: MapGraph, band: int, band_count: int) -> Array:
	var min_count := clampi(config.min_nodes_per_band, 1, 6)
	var max_count := maxi(clampi(config.max_nodes_per_band, 1, 6), min_count)
	var count := _rng.randi_range(min_count, max_count)
	var nodes: Array = []
	var y := float(band) / float(band_count - 1)
	for index in range(count):
		var base_x := (float(index) + 1.0) / (float(count) + 1.0)
		var x := clampf(base_x + _rng.randf_range(-config.horizontal_jitter, config.horizontal_jitter), 0.05, 0.95)
		nodes.append(graph.add_node(MapNode.Type.BATTLE, band, Vector2(x, y)))
	return nodes


## 返回距离 from 最近的若干个节点。
func _nearest_nodes(nodes: Array, from: Vector2, count: int) -> Array[MapNode]:
	var sorted: Array[MapNode] = []
	for node: MapNode in nodes:
		sorted.append(node)
	sorted.sort_custom(func(a: MapNode, b: MapNode) -> bool:
		return a.position.distance_squared_to(from) < b.position.distance_squared_to(from))
	var result: Array[MapNode] = []
	for index in range(mini(count, sorted.size())):
		result.append(sorted[index])
	return result


## 保证每个非起点层节点都有来自上一层的入边。
func _ensure_inbound_links(graph: MapGraph, bands: Array[Array]) -> void:
	for band in range(1, bands.size()):
		for node: MapNode in bands[band]:
			var has_inbound := false
			for neighbor_id in node.neighbor_ids:
				var neighbor := graph.get_node_by_id(neighbor_id)
				if neighbor != null and neighbor.band < node.band:
					has_inbound = true
					break
			if has_inbound:
				continue
			var previous := _nearest_nodes(bands[band - 1], node.position, 1)
			if not previous.is_empty():
				graph.link(node.id, previous[0].id)


## 随机添加隔层连边，形成可绕行的回路。
func _add_skip_links(graph: MapGraph, bands: Array[Array]) -> void:
	for band in range(0, bands.size() - 2):
		for node: MapNode in bands[band]:
			if _rng.randf() >= config.skip_band_link_chance:
				continue
			var target := _pick_near_node(bands[band + 2], node.position, 0.4)
			if target != null:
				graph.link(node.id, target.id)


## 随机添加近距离的额外连边，包含同层和回头路。
func _add_extra_links(graph: MapGraph) -> void:
	for node in graph.nodes:
		if _rng.randf() >= config.extra_link_chance:
			continue
		var pool: Array[MapNode] = []
		for other in graph.nodes:
			if other.id == node.id or node.neighbor_ids.has(other.id):
				continue
			if absi(other.band - node.band) > 2:
				continue
			if other.position.distance_to(node.position) > 0.35:
				continue
			pool.append(other)
		if not pool.is_empty():
			graph.link(node.id, pool[_rng.randi_range(0, pool.size() - 1)].id)


## 在指定层附近的节点中随机挑一个。
func _pick_near_node(nodes: Array, from: Vector2, max_distance: float) -> MapNode:
	var pool: Array[MapNode] = []
	for node: MapNode in nodes:
		if node.position.distance_to(from) <= max_distance:
			pool.append(node)
	if pool.is_empty():
		return null
	return pool[_rng.randi_range(0, pool.size() - 1)]


## 把无法从起点到达的节点接到最近的已连通节点上。
func _repair_connectivity(graph: MapGraph) -> void:
	var reachable := graph.collect_reachable_ids()
	var guard := graph.get_node_count() + 1
	while guard > 0:
		guard -= 1
		var unreachable_id := -1
		for node in graph.nodes:
			if not reachable.has(node.id):
				unreachable_id = node.id
				break
		if unreachable_id < 0:
			return
		var target := _find_nearest_reachable(graph, graph.get_node_by_id(unreachable_id), reachable)
		if target == null:
			return
		graph.link(unreachable_id, target.id)
		reachable = graph.collect_reachable_ids()


## 在已连通的节点中找距离最近的一个，优先选择相近的层。
func _find_nearest_reachable(graph: MapGraph, node: MapNode, reachable: Dictionary) -> MapNode:
	var best: MapNode = null
	var best_distance := INF
	for other in graph.nodes:
		if not reachable.has(other.id) or absi(other.band - node.band) > 2:
			continue
		var distance := other.position.distance_squared_to(node.position)
		if distance < best_distance:
			best_distance = distance
			best = other
	if best == null:
		for other in graph.nodes:
			if reachable.has(other.id):
				return other
	return best


## 随机分配节点类型，保证各类节点数量符合配置。
func _assign_types(graph: MapGraph) -> void:
	var pool: Array[MapNode] = []
	for node in graph.nodes:
		if node.type != MapNode.Type.START and node.type != MapNode.Type.BOSS:
			pool.append(node)
	_shuffle(pool)
	pool = _assign_type(pool, MapNode.Type.SHOP, config.shop_count)
	pool = _assign_type(pool, MapNode.Type.REST, config.rest_count)
	pool = _assign_type(pool, MapNode.Type.TREASURE, config.treasure_count)
	pool = _assign_elites(pool, config.elite_count)
	for node in pool:
		node.type = MapNode.Type.EVENT if _rng.randf() < config.event_ratio else MapNode.Type.BATTLE


## 把池中前 count 个节点设为指定类型，返回剩余的节点。
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


## 精英不放在紧邻起点的一层，避免开局无路可走。
func _assign_elites(pool: Array[MapNode], count: int) -> Array[MapNode]:
	var remaining: Array[MapNode] = []
	var assigned := 0
	for node in pool:
		if assigned < count and node.band >= 2:
			node.type = MapNode.Type.ELITE
			assigned += 1
		else:
			remaining.append(node)
	return remaining


## 用生成器自带的随机数洗牌。
func _shuffle(items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var temp: Variant = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temp
