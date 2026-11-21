## 地图生成的可调参数，在检查器里为每局游戏指定一份配置。
class_name MapConfig
extends Resource

## 地图包含的层数，含起点层和 Boss 层。
@export_range(3, 12) var band_count: int = 7
## 中间层每层最少的节点数。
@export_range(1, 6) var min_nodes_per_band: int = 2
## 中间层每层最多的节点数。
@export_range(1, 6) var max_nodes_per_band: int = 4
## 节点横向位置的随机抖动，0 表示按层等距排列。
@export_range(0.0, 0.45) var horizontal_jitter: float = 0.08
## 每个节点向下一层连出的边数。
@export_range(1, 4) var links_per_node: int = 2
## 隔层连边的概率，用来制造网状回路。
@export_range(0.0, 1.0) var skip_band_link_chance: float = 0.18
## 额外连边的概率，进一步增加可回头的路径。
@export_range(0.0, 1.0) var extra_link_chance: float = 0.15
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
