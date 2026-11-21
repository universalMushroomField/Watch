## 地图生成的可调参数，在检查器里为每局游戏指定一份配置。
class_name MapConfig
extends Resource

## 地图包含的层数，含起点层和 Boss 层。层数越多，环与环之间越密。
@export_range(3, 12) var band_count: int = 7
## 中间层每层最少的节点数。
@export_range(1, 6) var min_nodes_per_band: int = 3
## 中间层每层最多的节点数。
@export_range(1, 6) var max_nodes_per_band: int = 5
## 同层至少 4 个节点时，相邻节点之间连成弧线的概率。
@export_range(0.0, 1.0) var ring_link_chance: float = 0.55
## 精英节点的数量。
@export_range(0, 4) var elite_count: int = 2
## 商店节点的数量。
@export_range(0, 3) var shop_count: int = 1
## 休息节点的数量。
@export_range(0, 3) var rest_count: int = 1
## 宝箱节点的数量。
@export_range(0, 3) var treasure_count: int = 1
## 剩余节点中成为未知事件的概率，其余为普通战斗。
@export_range(0.0, 1.0) var event_ratio: float = 0.5
