## 六边形棋盘的逻辑尺寸。
##
## 中间区域是一个 [member columns] × [member rows] 的完整矩形蜂巢；起点单独
## 占最左一列，Boss 单独占最右一列，因此总列数是 [code]columns + 2[/code]。
class_name HexLayout
extends RefCounted

const SQRT3 := 1.7320508075688772

## 中间区域的列数，不含起点列和 Boss 列。
var columns: int
## 中间区域的行数。
var rows: int
## 六边形的外接圆半径，世界单位。
var hex_radius: float


func _init(
		interior_columns: int = MapConfig.DEFAULT_COLUMNS,
		interior_rows: int = MapConfig.DEFAULT_ROWS,
		radius: float = MapConfig.DEFAULT_HEX_RADIUS,
) -> void:
	columns = maxi(interior_columns, 1)
	rows = maxi(interior_rows, 2)
	hex_radius = maxf(radius, 0.1)


## 无地形和相机的逻辑生成使用配置目标值。
static func from_config(config: MapConfig) -> HexLayout:
	return HexLayout.new(maxi(config.max_columns, 2), maxi(config.max_rows, 2), maxf(config.hex_radius, 0.5))


## 包含起点列和 Boss 列的总列数。
func get_total_columns() -> int:
	return columns + 2


## 起点与 Boss 所在的行，取中间一行。
func get_middle_row() -> int:
	return rows >> 1


## 尖顶六边形水平方向相邻列的中心距。
func get_column_step() -> float:
	return SQRT3 * hex_radius


## 尖顶六边形相邻行的中心距。
func get_row_step() -> float:
	return 1.5 * hex_radius


## 棋盘（含六边形自身宽度）在 X 方向的总跨度；奇数行会再错开半列。
func get_world_width() -> float:
	return get_column_step() * (float(get_total_columns()) + 0.5)


## 棋盘（含六边形自身高度）在 Z 方向的总跨度。
func get_world_depth() -> float:
	return get_row_step() * float(maxi(rows - 1, 0)) + hex_radius * 2.0
