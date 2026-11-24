## 地图生成参数。
##
## 棋盘是六边形蜂巢：中间是 [member max_columns] × [member max_rows] 的完整
## 矩形，起点和 Boss 各占最左/最右一列。实际列数和行数会按地形与相机可视
## 范围缩小，见 [MapHexLayer.make_layout]。
class_name MapConfig
extends Resource

const DEFAULT_COLUMNS := 4
const DEFAULT_ROWS := 4
const DEFAULT_HEX_RADIUS := 4.2

@export_group("Hex Board")
## 中间区域的最大列数。
@export_range(2, 24) var max_columns: int = DEFAULT_COLUMNS
## 中间区域的最大行数。
@export_range(2, 12) var max_rows: int = DEFAULT_ROWS
## 六边形外接圆半径的目标值，单位与世界坐标一致。
@export var hex_radius: float = DEFAULT_HEX_RADIUS
## 六边形在平滑地表高度之上额外抬升的距离。
@export var hex_lift: float = 0.25
## 棋盘与地形边缘保留的空白，单位与世界坐标一致。
@export var board_margin: float = 0.5

@export_group("Node Types")
## 精英战数量。
@export var elite_count: int = 2
## 商店数量。
@export var shop_count: int = 1
## 休息点数量。
@export var rest_count: int = 1
## 宝箱数量。
@export var treasure_count: int = 1
## 普通战斗被替换成未知事件的概率。
@export_range(0.0, 1.0) var event_ratio: float = 0.5
