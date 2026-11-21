## 放射状地图中的一个节点。
class_name MapNode
extends RefCounted

## 节点类型，决定进入时触发的内容。
enum Type { START, BATTLE, ELITE, EVENT, TREASURE, SHOP, REST, BOSS }

## 节点类型的中文名，界面和日志共用。
const TYPE_LABELS := {
	Type.START: "起点",
	Type.BATTLE: "战斗",
	Type.ELITE: "精英战斗",
	Type.EVENT: "未知事件",
	Type.TREASURE: "宝箱",
	Type.SHOP: "商店",
	Type.REST: "休息点",
	Type.BOSS: "关底 Boss",
}

## 节点类型的单字缩写，画在地图节点上。
const TYPE_SHORT_LABELS := {
	Type.START: "起",
	Type.BATTLE: "战",
	Type.ELITE: "精",
	Type.EVENT: "?",
	Type.TREASURE: "宝",
	Type.SHOP: "商",
	Type.REST: "休",
	Type.BOSS: "王",
}

## 节点在本次地图中的唯一编号。
var id: int
## 节点类型。
var type: Type = Type.BATTLE
## 节点所在的层，起点为 0，Boss 层为最后一层。
var band: int = 0
## 归一化坐标，Boss 在 (0.5, 0.5)，其余节点按层环绕。
var position := Vector2.ZERO
## 相连节点的编号。边没有方向，但已探索节点不能再次进入。
var neighbor_ids: Array[int] = []
## 玩家是否到过该节点。
var visited := false


func _init(node_id: int = -1, node_type: Type = Type.BATTLE, node_band: int = 0, node_position := Vector2.ZERO) -> void:
	id = node_id
	type = node_type
	band = node_band
	position = node_position


## 返回节点类型的中文名。
func get_type_label() -> String:
	return TYPE_LABELS.get(type, "未知")


## 返回画在地图上的单字缩写。
func get_short_label() -> String:
	return TYPE_SHORT_LABELS.get(type, "?")


## 战斗、精英和 Boss 节点都视为战斗节点。
func is_combat() -> bool:
	return type == Type.BATTLE or type == Type.ELITE or type == Type.BOSS
