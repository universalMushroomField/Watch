## 美术 32 色的运行时取色入口。
##
## 唯一真源是 `res://public/color_palette_art.tres`，这里只存「语义 → 下标」，不存色值。
## 改色板即全局生效；重排色板会静默改掉下面所有下标，和 `.tres` 里按枚举下标序列化的字段同理。
class_name ArtPalette
extends RefCounted

const PATH := "res://public/color_palette_art.tres"

## 地图底模。
const TERRAIN := 4
## 底模之外的背景板，取色板最深的蓝紫。
const BACKGROUND := 14
## 平行光颜色，与底模同色。
const LIGHT := 4
## 粒子雾贴近地表的颜色，沿用暖色阶。
const FOG_SURFACE := 3
## 粒子雾远端颜色，冷色与暖底模分层。
const FOG_MIST := 19
## 贴地折线与交互折线。
const PATH_LINE := 28
## 折线透明度；色板色本身都是不透明的。
const PATH_LINE_ALPHA := 0.65
## 当前节点标签。
const LABEL_CURRENT := 4
## 悬停节点标签。
const LABEL_HOVER := 24
## 已访问且不是当前节点的标签。
const LABEL_VISITED := 29

static var _colors := PackedColorArray()
static var _loaded := false


## 取色板第 [param index] 色；越界时报错并返回白色。
static func color(index: int) -> Color:
	if not _loaded:
		_loaded = true
		var palette := load(PATH) as ColorPalette
		if palette == null:
			push_error("无法加载色板：%s" % PATH)
		else:
			_colors = palette.colors
	if index < 0 or index >= _colors.size():
		push_error("色板下标越界：%d（共 %d 色）" % [index, _colors.size()])
		return Color.WHITE
	return _colors[index]


## 比 [param index] 暗一阶的颜色，用于不可达状态；已是最暗一阶时返回原色。
static func darker(index: int) -> Color:
	return color(maxi(index - 1, 0))