## 地图蜂巢顶点上的一个地点。
class_name MapNode
extends RefCounted

## 地点类型。
enum Type {
	START,
	BATTLE,
	ELITE,
	EVENT,
	SHOP = 5,
	REST,
	BOSS,
	HUB,
}

const TYPE_LABELS := {
	Type.START: "起点",
	Type.BATTLE: "战斗",
	Type.ELITE: "精英战斗",
	Type.EVENT: "未知事件",
	Type.SHOP: "商店",
	Type.REST: "休息点",
	Type.BOSS: "本幕 Boss",
	Type.HUB: "枢纽",
}

const TYPE_SHORT_LABELS := {
	Type.START: "起",
	Type.BATTLE: "战",
	Type.ELITE: "精",
	Type.EVENT: "事",
	Type.SHOP: "商",
	Type.REST: "息",
	Type.BOSS: "Boss",
	Type.HUB: "枢",
}

## 节点编号，在一张图内唯一。
var id: int
## 地点类型。
var type: Type
## 蜂巢顶点的横向整数坐标。
var column: int
## 蜂巢顶点的纵向整数坐标。
var row: int
## 蜂巢顶点的整数坐标。
var vertex: Vector2i
## 相邻地点的编号。
var neighbor_ids: Array[int] = []
## 是否已经被玩家访问过。
var visited: bool = false


func _init(
		node_id: int = -1,
		node_type: Type = Type.BATTLE,
		node_column: int = 0,
		node_row: int = 0,
) -> void:
	id = node_id
	type = node_type
	column = node_column
	row = node_row


## 类型的中文名称。
func get_type_label() -> String:
	return TYPE_LABELS.get(type, "未知")


## 绘制在六边形上的短标签。
func get_short_label() -> String:
	return TYPE_SHORT_LABELS.get(type, "?")


## 该地点是否会进入战斗。
func is_combat() -> bool:
	return type == Type.BATTLE or type == Type.ELITE or type == Type.BOSS
