class_name MapRun
extends RefCounted

## 第一次进入某个节点。
signal node_entered(node: MapNode)
## 目标节点不可前往：已被探索、不是已探索节点的邻居，或本幕已经结束。
signal node_travel_rejected(node_id: int)
## 崩解度变化。
signal decay_changed(ratio: float)

## 地图生成参数。
var config: MapConfig
## 当前幕的地图。
var graph: MapGraph
## 当前幕使用的六边形布局。
var layout: HexLayout
## 玩家当前所在节点编号。
var current_id: int = -1

const STAGE_STEPS := [0, 12, 24, 32, 48, 64]
const STAGE_NAMES := ["生境扩张", "菌核耐火化", "假性隐生化", "根系耗地化", "侵略性拟态", "自毁性利己"]

signal first_hub_activated(node: MapNode)
var extreme_steps := 0
var _hub_support_used := false
var _visited_ids := {}


func _init(map_config: MapConfig, hex_layout: HexLayout) -> void:
	config = map_config
	layout = hex_layout


## 根据本幕种子重新生成地图，清空幕内探索记录。
func generate(act_seed: int) -> void:
	assert(layout != null, "创建地图前必须提供拟合后的棋盘布局。")
	graph = MapGenerator.new(config, layout).generate(act_seed)
	_visited_ids.clear()
	_hub_support_used = false
	current_id = graph.start_id
	_mark_visited(current_id)
	decay_changed.emit(get_decay_ratio())


## 当前所在节点。
func get_current_node() -> MapNode:
	return graph.get_node_by_id(current_id)


## 当前可以前往的节点：所有已探索节点的未探索邻居。本幕结束后返回空数组。
func get_reachable_nodes() -> Array[MapNode]:
	var result: Array[MapNode] = []
	if graph == null or is_act_cleared():
		return result
	var seen := {}
	for visited_id in _visited_ids:
		var visited_node := graph.get_node_by_id(visited_id)
		if visited_node == null:
			continue
		for neighbor_id in visited_node.neighbor_ids:
			if seen.has(neighbor_id):
				continue
			var neighbor := graph.get_node_by_id(neighbor_id)
			if neighbor == null or neighbor.visited:
				continue
			seen[neighbor_id] = true
			result.append(neighbor)
	return result


## 目标节点是否可以从某个已探索节点前往。已探索的节点不能再次进入。
func can_travel_to(node_id: int) -> bool:
	if graph == null or is_act_cleared():
		return false
	var node := graph.get_node_by_id(node_id)
	if node == null or node.visited:
		return false
	for visited_id in _visited_ids:
		var visited_node := graph.get_node_by_id(visited_id)
		if visited_node != null and visited_node.neighbor_ids.has(node_id):
			return true
	return false


## 从当前节点走到目标节点的最短路径（节点编号序列），找不到时返回空数组。
## 中间步骤只经过已探索节点；目标本身还没探索时，最后一步是从最近的已探索邻居跨过去。
func find_path_to(node_id: int) -> Array[int]:
	var result: Array[int] = []
	if graph == null or graph.get_node_by_id(current_id) == null or graph.get_node_by_id(node_id) == null:
		return result
	if node_id == current_id:
		result.append(current_id)
		return result

	var previous := {}
	var depth := {current_id: 0}
	var queue: Array[int] = [current_id]
	var head := 0
	while head < queue.size():
		var from_id := queue[head]
		head += 1
		var from := graph.get_node_by_id(from_id)
		if from == null:
			continue
		for neighbor_id in from.neighbor_ids:
			if depth.has(neighbor_id):
				continue
			var neighbor := graph.get_node_by_id(neighbor_id)
			if neighbor == null:
				continue
			if neighbor_id != node_id and not neighbor.visited:
				continue
			previous[neighbor_id] = from_id
			depth[neighbor_id] = depth[from_id] + 1
			if neighbor_id == node_id:
				head = queue.size()
				break
			queue.append(neighbor_id)

	if not depth.has(node_id):
		return result
	var step := node_id
	while true:
		result.push_front(step)
		if step == current_id:
			break
		step = previous[step]
	return result


## 移动到某个已探索节点的相邻节点。新节点会触发 node_entered 并提高崩解度。
func travel_to(node_id: int) -> bool:
	if not can_travel_to(node_id):
		node_travel_rejected.emit(node_id)
		return false
	current_id = node_id
	var node := graph.get_node_by_id(node_id)
	_mark_visited(node_id)
	extreme_steps += 1
	if node.type == MapNode.Type.HUB and not _hub_support_used:
		_hub_support_used = true
		first_hub_activated.emit(node)
	decay_changed.emit(get_decay_ratio())
	node_entered.emit(node)
	return true


## Boss 是否已经被访问，本幕是否已经结束。
func is_act_cleared() -> bool:
	var boss := graph.get_node_by_id(graph.boss_id) if graph != null else null
	return boss != null and boss.visited


## 已访问的节点数量。
func get_visited_count() -> int:
	return _visited_ids.size()


## 地图节点总数。
func get_total_node_count() -> int:
	return graph.get_node_count() if graph != null else 0


## 参与崩解度计算的已访问节点数，起点不计入。
func get_decay_visited_count() -> int:
	var count := get_visited_count()
	if graph != null and _visited_ids.has(graph.start_id):
		count -= 1
	return maxi(count, 0)


## 参与崩解度计算的节点总数，起点不计入。
func get_decay_total_count() -> int:
	return maxi(get_total_node_count() - 1, 0)


func get_extreme_stage() -> int:
	return STAGE_STEPS.bsearch(extreme_steps, false) - 1


func get_decay_ratio() -> float:
	return minf(float(extreme_steps) / STAGE_STEPS.back(), 1.0)


func _mark_visited(node_id: int) -> void:
	if node_id < 0:
		return
	_visited_ids[node_id] = true
	var node := graph.get_node_by_id(node_id)
	if node != null:
		node.visited = true
