## 地图节点使用的内容池：事件、商店和各类节点的占位奖励。
class_name MapContentPool
extends Resource

## 可随机到的未知事件。
@export var events: Array[MapEventData] = []
## 商店库存。
@export var shop_stock: ShopStockData
## 普通战斗金币下限。
@export var battle_gold_min: int = 10
## 普通战斗金币上限。
@export var battle_gold_max: int = 20
## 精英战斗金币下限。
@export var elite_gold_min: int = 25
## 精英战斗金币上限。
@export var elite_gold_max: int = 40
## 休息点恢复的生命上限比例。
@export_range(0.0, 1.0) var rest_heal_ratio: float = 0.3
