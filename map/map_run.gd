## 推进一幕地图：当前位置、已探索节点和崩解度。
##
## 崩解度 = 已访问节点数 / 地图节点总数，每进入一个新节点上升，
## 进入下一幕时随新地图一起重置。具体减益效果暂未实现，先通过
## decay_changed 信号和 get_decay_ratio() 提供给后续系统使用。
class_name MapRun
extends RefCounted

## 新的一幕开始，地图已生成。
signal act_started(act_index: int, graph: MapGraph)
## 一幕结束（调用 advance_act 时触发）。
signal act_completed(act_index: int, decay_ratio: float)
## 第一次进入某个节点。
signal node_entered(node: MapNode)
## 目标节点不可前往：已被探索、不是已探索节点的邻居，或本幕已经结束。
signal node_travel_rejected(node_id: int)
## 崩解度变化。
signal decay_changed(ratio: float)

## 地图生成参数。
var config: MapConfig
## 玩家状态。
var player: MapPlayerState
## 当前幕的地图。
var graph: MapGraph
## 当前幕的序号，从 0 开始。
var act_index: int = 0
## 玩家当前所在节点编号。
var current_id: int = -1

var _visited_ids := {}
var _rng := RandomNumberGenerator.new()
var _run_seed: int = 0


func _init(map_config: MapConfig = null, player_state: MapPlayerState = null, seed_value: int = -1) -> void:
	config = map_config if map_config != null else MapConfig.new()
	player = player_state if player_state != null else MapPlayerState.new()
	if seed_value >= 0:
		_run_seed = seed_value
		_rng.seed = seed_value
	else:
		_rng.randomize()
		_run_seed = _rng.randi()
	start_act(0)


## 开始指定幕，生成新地图并重置崩解度。
func start_act(index: int) -> void:
	act_index = maxi(index, 0)
	graph = MapGenerator.new(config).generate(_run_seed + act_index * 7919)
	_visited_ids.clear()
	current_id = graph.start_id
	_mark_visited(current_id)
	act_started.emit(act_index, graph)
	decay_changed.emit(get_decay_ratio())


## 结束当前幕并进入下一幕。
func advance_act() -> void:
	act_completed.emit(act_index, get_decay_ratio())
	start_act(act_index + 1)


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


## 移动到某个已探索节点的相邻节点。新节点会触发 node_entered 并提高崩解度。
func travel_to(node_id: int) -> bool:
	if not can_travel_to(node_id):
		node_travel_rejected.emit(node_id)
		return false
	current_id = node_id
	var node := graph.get_node_by_id(node_id)
	_mark_visited(node_id)
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


## 崩解度，范围 0~1。起点不参与计算，因此开局为 0。
func get_decay_ratio() -> float:
	var total := get_decay_total_count()
	if total <= 0:
		return 0.0
	return float(get_decay_visited_count()) / float(total)


func _mark_visited(node_id: int) -> void:
	if node_id < 0:
		return
	_visited_ids[node_id] = true
	var node := graph.get_node_by_id(node_id)
	if node != null:
		node.visited = true
