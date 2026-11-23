## 六边形蜂巢地图生成器。
##
## 结构：最左一列只有一个起点，最右一列只有一个 Boss，中间是完整的
## [member HexLayout.columns] × [member HexLayout.rows] 矩形蜂巢。所有物理
## 相邻的六边形直接连边，因此保留“已探索节点的未探索邻居都可走”的规则。
class_name MapGenerator
extends RefCounted

## 偶数列（column 为偶数）的六个邻居偏移。
const EVEN_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, -1),
	Vector2i(-1, 0),
	Vector2i(0, 1),
]

## 奇数列（column 为奇数）的六个邻居偏移。
const ODD_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

var config: MapConfig
var layout: HexLayout
var _rng := RandomNumberGenerator.new()


func _init(map_config: MapConfig = null, hex_layout: HexLayout = null) -> void:
	config = map_config if map_config != null else MapConfig.new()
	layout = hex_layout if hex_layout != null else HexLayout.new()


## 生成一张地图。[param seed_value] 小于 0 时随机取种子。
func generate(seed_value: int = -1) -> MapGraph:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()

	var graph := MapGraph.new()
	graph.layout = layout

	var middle_row := layout.get_middle_row()
	var start := graph.add_node(MapNode.Type.START, 0, middle_row)
	var cells := {Vector2i(0, middle_row): start}

	for column in range(1, layout.columns + 1):
		for row in range(layout.rows):
			cells[Vector2i(column, row)] = graph.add_node(MapNode.Type.BATTLE, column, row)

	var boss_column := layout.get_total_columns() - 1
	var boss := graph.add_node(MapNode.Type.BOSS, boss_column, middle_row)
	cells[Vector2i(boss_column, middle_row)] = boss

	_connect_hex_neighbors(graph, cells)
	_assign_types(graph)
	return graph


## 把所有相邻的六边形连起来。
func _connect_hex_neighbors(graph: MapGraph, cells: Dictionary) -> void:
	for cell_key in cells.keys():
		var cell: Vector2i = cell_key
		var node: MapNode = cells[cell]
		var offsets := ODD_NEIGHBORS if (cell.x & 1) == 1 else EVEN_NEIGHBORS
		for offset in offsets:
			var neighbor_key := cell + offset
			if cells.has(neighbor_key):
				graph.link(node.id, cells[neighbor_key].id)


## 随机分配精英、商店、休息、宝箱、事件和普通战斗。
func _assign_types(graph: MapGraph) -> void:
	var pool: Array[MapNode] = []
	for node in graph.nodes:
		if node.type == MapNode.Type.START or node.type == MapNode.Type.BOSS:
			continue
		pool.append(node)
	_shuffle(pool)

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