## 一张自由网状地图：节点集合、无向连边和起终点。
class_name MapGraph
extends RefCounted

## 地图中的全部节点，下标与节点编号一致。
var nodes: Array[MapNode] = []
## 起点节点编号。
var start_id: int = -1
## Boss 节点编号。
var boss_id: int = -1


## 创建并加入一个新节点，返回该节点。
func add_node(node_type: MapNode.Type, node_band: int, position: Vector2) -> MapNode:
	var node := MapNode.new(nodes.size(), node_type, node_band, position)
	nodes.append(node)
	if node_type == MapNode.Type.START:
		start_id = node.id
	elif node_type == MapNode.Type.BOSS:
		boss_id = node.id
	return node


## 按编号取节点，编号无效时返回 null。
func get_node_by_id(node_id: int) -> MapNode:
	if node_id < 0 or node_id >= nodes.size():
		return null
	return nodes[node_id]


## 连接两个节点。边无方向，重复连接会被忽略。
func link(node_a: int, node_b: int) -> void:
	if node_a == node_b:
		return
	var a := get_node_by_id(node_a)
	var b := get_node_by_id(node_b)
	if a == null or b == null:
		return
	if not a.neighbor_ids.has(node_b):
		a.neighbor_ids.append(node_b)
	if not b.neighbor_ids.has(node_a):
		b.neighbor_ids.append(node_a)


## 返回指定节点的相邻节点。
func get_neighbor_nodes(node_id: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	var node := get_node_by_id(node_id)
	if node == null:
		return result
	for neighbor_id in node.neighbor_ids:
		var neighbor := get_node_by_id(neighbor_id)
		if neighbor != null:
			result.append(neighbor)
	return result


## 地图中的节点总数。
func get_node_count() -> int:
	return nodes.size()


## 从起点出发能到达的节点编号集合。
func collect_reachable_ids() -> Dictionary:
	var reachable := {}
	if start_id < 0:
		return reachable
	var queue: Array[int] = [start_id]
	reachable[start_id] = true
	while not queue.is_empty():
		var node_id: int = queue.pop_back()
		var node := get_node_by_id(node_id)
		if node == null:
			continue
		for neighbor_id in node.neighbor_ids:
			if not reachable.has(neighbor_id):
				reachable[neighbor_id] = true
				queue.append(neighbor_id)
	return reachable


## 返回从起点无法到达的节点编号。
func find_unreachable_ids() -> Array[int]:
	var reachable := collect_reachable_ids()
	var unreachable: Array[int] = []
	for node in nodes:
		if not reachable.has(node.id):
			unreachable.append(node.id)
	return unreachable


## 是否所有节点都能从起点到达。
func is_fully_connected() -> bool:
	return start_id >= 0 and find_unreachable_ids().is_empty()
