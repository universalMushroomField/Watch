## 全局色板的运行时取色入口。
##
## 唯一真源是 `res://public/color_base.tres`，这里只存「语义 → 下标」，不存色值。
## 运行时取色以此色板为准；重排色板会静默改掉下面所有下标，和 `.tres` 里按枚举下标序列化的字段同理。
class_name ArtPalette
extends RefCounted

const PATH := "res://public/color_base.tres"

## 地图底模。
const TERRAIN := 14
## 底模之外的背景板，取色板最深的蓝紫。
const BACKGROUND := 30
## 平行光使用浅灰，保留地表暖色。
const LIGHT := 44
const SHADOW_DEEP := 30
const SHADOW_MIDDLE := 31
const SHADOW_EDGE := 32
## 粒子雾贴近地表的颜色，沿用暖色阶。
const FOG_SURFACE := 14
## 粒子雾远端颜色，冷色与暖底模分层。
const FOG_MIST := 34
## 贴地折线与交互折线。
const PATH_LINE := 37
## 折线透明度；色板色本身都是不透明的。
const PATH_LINE_ALPHA := 0.65
## 悬停节点时高亮出来的那条路径。
const PATH_HOVER := 9
## 高亮路径的不透明度，比普通折线更实。
const PATH_HOVER_ALPHA := 0.95
## 当前节点标记：玩家所在节点的球、标签和玩家标记统一用这一色。
const NODE_CURRENT := 17
## 已访问节点（不是玩家所在处）：球与标签统一换成这一色，与所有地点类型色都不撞。
const NODE_VISITED := 13
## 可前往节点的环形标记。
const NODE_REACHABLE := 7
## 鼠标悬停节点的标签与环形标记。
const NODE_HOVER := 44
## 玩家所在节点标签的色：压在 NODE_CURRENT 的实心圆底上，要靠对比读字。
const NODE_CURRENT_LABEL := 44
## 未到达节点向地表色淡出的比例，越大越淡；降低未到达节点与地表的对比。
const NODE_UNREACHED_FADE := 0.55

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


## 把第 [param index] 色向底模色淡出 [param amount]（0~1），用于「还没走到、先不抢眼」的状态。
static func fade(index: int, amount: float) -> Color:
	return color(index).lerp(color(TERRAIN), clampf(amount, 0.0, 1.0))
