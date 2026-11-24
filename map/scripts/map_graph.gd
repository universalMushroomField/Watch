## 一张地图的图结构：六边形格子、节点之间的连通关系，以及起点和 Boss。
class_name MapGraph
extends RefCounted

const SQRT3 := 1.7320508075688772

## 所有地点，按编号索引。
var nodes: Array[MapNode] = []
## 起点编号。
var start_id: int = -1
## Boss 编号。
var boss_id: int = -1
## 这张图使用的六边形布局。
var layout: HexLayout


## 新建一个地点并返回它。
func add_node(node_type: MapNode.Type, column: int, row: int) -> MapNode:
	var node := MapNode.new(nodes.size(), node_type, column, row)
	nodes.append(node)
	if node_type == MapNode.Type.START:
		start_id = node.id
	elif node_type == MapNode.Type.BOSS:
		boss_id = node.id
	return node


## 双向连接两个地点。
func link(a_id: int, b_id: int) -> void:
	if a_id == b_id:
		return
	var a := get_node_by_id(a_id)
	var b := get_node_by_id(b_id)
	if a == null or b == null:
		return
	if not a.neighbor_ids.has(b_id):
		a.neighbor_ids.append(b_id)
	if not b.neighbor_ids.has(a_id):
		b.neighbor_ids.append(a_id)


## 按编号取地点，不存在时返回 null。
func get_node_by_id(node_id: int) -> MapNode:
	for node in nodes:
		if node.id == node_id:
			return node
	return null


## 按六边形坐标取地点，不存在时返回 null。
func find_node_at(column: int, row: int) -> MapNode:
	for node in nodes:
		if node.column == column and node.row == row:
			return node
	return null


## 地图的节点总数。
func get_node_count() -> int:
	return nodes.size()


## 地图的列数（含起点列和 Boss 列）。
func get_column_count() -> int:
	if layout != null:
		return layout.get_total_columns()
	var count := 0
	for node in nodes:
		count = maxi(count, node.column + 1)
	return count


## 地图的行数。
func get_row_count() -> int:
	if layout != null:
		return layout.rows
	var count := 0
	for node in nodes:
		count = maxi(count, node.row + 1)
	return count


## 从指定地点出发、只沿邻接边能到达的所有地点编号。
func collect_reachable_ids(from_id: int) -> Array[int]:
	var result: Array[int] = []
	var start := get_node_by_id(from_id)
	if start == null:
		return result
	var queue: Array[int] = [from_id]
	var seen := {from_id: true}
	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		result.append(current_id)
		var current := get_node_by_id(current_id)
		if current == null:
			continue
		for neighbor_id in current.neighbor_ids:
			if not seen.has(neighbor_id):
				seen[neighbor_id] = true
				queue.append(neighbor_id)
	return result


## 所有地点是否都从起点可达。
func is_fully_connected() -> bool:
	if start_id < 0:
		return false
	return collect_reachable_ids(start_id).size() == nodes.size()