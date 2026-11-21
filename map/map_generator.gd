## 生成放射状地图：Boss 在中心，其余节点按层环绕，连线不会交叉。
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

	# 先建节点，角度和位置稍后统一计算。
	var start := graph.add_node(MapNode.Type.START, 0, Vector2.ZERO)
	bands.append([start])
	for band in range(1, band_count - 1):
		bands.append(_create_band(graph, band))
	var boss := graph.add_node(MapNode.Type.BOSS, band_count - 1, Vector2.ZERO)
	bands.append([boss])

	var angles := _assign_angles(bands, band_count)
	# 只需要副作用（连边），返回值不再使用。
	_assign_parents(graph, bands, angles)
	_apply_positions(graph, angles, band_count)

	# 同层相邻节点之间补弧线边，增加可绕行的路线。
	for band in range(1, band_count - 1):
		_add_ring_links(graph, bands[band], angles)

	_assign_types(graph)
	return graph


## 在指定层随机摆放节点，位置稍后按角度计算。
func _create_band(graph: MapGraph, band: int) -> Array:
	var min_count := clampi(config.min_nodes_per_band, 1, 6)
	var max_count := maxi(clampi(config.max_nodes_per_band, 1, 6), min_count)
	var count := _rng.randi_range(min_count, max_count)
	# 最外圈固定 4 个节点，保证起点四周有一圈完整的环，而不是一条孤立的长边。
	if band == 1:
		count = clampi(4, min_count, max_count)
	var nodes: Array = []
	for _index in range(count):
		nodes.append(graph.add_node(MapNode.Type.BATTLE, band, Vector2.ZERO))
	return nodes


## 每层节点沿圆周等距分布，起点固定在 0 度。
func _assign_angles(bands: Array[Array], band_count: int) -> Dictionary:
	var angles := {}
	for band in range(bands.size()):
		var nodes: Array = bands[band]
		if band == band_count - 1:
			angles[nodes[0].id] = 0.0
			continue
		var step := TAU / float(nodes.size())
		# 最外两层保持 0 度对齐，让起点到门节点的连线最短；更内层错开半个间隔。
		var offset := 0.0 if band <= 1 or band % 2 == 0 else step * 0.5
		for index in range(nodes.size()):
			angles[nodes[index].id] = offset + step * float(index)
	return angles


## 每个节点连向角度最近的内层节点，保证同一扇区内的连线不会交叉。
func _assign_parents(graph: MapGraph, bands: Array[Array], angles: Dictionary) -> Dictionary:
	var parents := {}
	for band in range(bands.size() - 1):
		var candidates: Array = bands[band + 1]
		for node: MapNode in bands[band]:
			var parent: MapNode = candidates[0]
			var best_distance := INF
			for candidate: MapNode in candidates:
				var distance := absf(wrapf(angles[candidate.id] - angles[node.id], -PI, PI))
				if distance < best_distance:
					best_distance = distance
					parent = candidate
			parents[node.id] = parent.id
			graph.link(node.id, parent.id)
	return parents


## 把角度和层数换算成归一化坐标，Boss 固定在正中心。
func _apply_positions(graph: MapGraph, angles: Dictionary, band_count: int) -> void:
	var outer := float(band_count - 1)
	for node in graph.nodes:
		if node.type == MapNode.Type.BOSS:
			node.position = Vector2(0.5, 0.5)
			continue
		var radius := 0.5 * float(band_count - 1 - node.band) / outer
		var angle: float = angles.get(node.id, 0.0)
		node.position = Vector2(0.5 + cos(angle) * radius, 0.5 + sin(angle) * radius)


## 同一层角度相邻的节点之间按概率补一条弧线边。
func _add_ring_links(graph: MapGraph, nodes: Array, angles: Dictionary) -> void:
	# 节点太少时环向弧线会横跨半张地图，只给至少 4 个节点的层加捷径。
	if nodes.size() < 4:
		return
	var ring: Array = nodes.duplicate()
	ring.sort_custom(func(a: MapNode, b: MapNode) -> bool:
		return angles[a.id] < angles[b.id])
	var max_gap := TAU / 4.0 + 0.001
	for index in range(ring.size()):
		var next_index := (index + 1) % ring.size()
		var gap := absf(angles[ring[next_index].id] - angles[ring[index].id])
		if gap > PI:
			gap = TAU - gap
		if gap > max_gap:
			continue
		if _rng.randf() < config.ring_link_chance:
			graph.link_ring(ring[index].id, ring[next_index].id)


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
