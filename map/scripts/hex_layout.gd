## 六边形棋盘的逻辑尺寸。
##
## 中间区域是一个 [member columns] × [member rows] 的完整矩形蜂巢；起点单独
## 占最左一列，Boss 单独占最右一列，因此总列数是 [code]columns + 2[/code]。
##
## 实机布局一律用 [method fit] 按可用矩形拟合；不要拿 [MapConfig] 的上限
## 直接构造布局，那样会超出地形和相机可视范围。
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


## 按可用矩形拟合一盘布局。
##
## [param rect] 是地形与相机共同决定、棋盘可以占用的世界 XZ 矩形，
## [param config] 只提供上限（[member MapConfig.max_columns]、
## [member MapConfig.max_rows]）和目标半径（[member MapConfig.hex_radius]）。
## 返回布局保证 [method get_world_width] 不超过 [code]rect.size.x[/code]、
## [method get_world_depth] 不超过 [code]rect.size.y[/code]，且半径不超过目标半径。
## 因此列数、行数通常小于上限——这是预期行为，上限不是目标值。
## 矩形小于约 0.8 × 0.4 米时半径会被 [method _init] 的下限夹住，不再保证。
static func fit(rect: Rect2, config: MapConfig) -> HexLayout:
	var target_radius := maxf(config.hex_radius, 0.1)
	var max_columns := maxi(config.max_columns, 2)
	var max_rows := maxi(config.max_rows, 2)
	var columns := int(floor(rect.size.x / (SQRT3 * target_radius) - 2.5))
	var rows := int(floor((rect.size.y / target_radius - 0.5) / 1.5))
	columns = clampi(columns, 2, max_columns)
	rows = clampi(rows, 2, max_rows)

	# 用实际列数反算半径：跨度公式正是 get_world_width()/get_world_depth()，
	# 取两者能容纳的最小半径就保证棋盘落在矩形内。
	var span_columns := SQRT3 * (float(columns) + 2.5)
	var span_rows := 1.5 * float(rows) + 0.5
	var radius := minf(rect.size.x / span_columns, rect.size.y / span_rows)
	return HexLayout.new(columns, rows, minf(radius, target_radius))


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
