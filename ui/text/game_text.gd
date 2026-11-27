@tool
## 全局界面文案。固定的界面文字集中在这一份资源里，改文案只改 [code]ui/text/game_text.tres[/code]。
##
## 货币名也放在这里：以后把「活性精珀」改名，连带范围只有这一个文件，不用翻脚本和场景。
## 带 [code]%d[/code]/[code]%s[/code] 的字段是格式串，参数含义写在各自的注释里。
class_name GameText
extends Resource

## 共享文案资源的默认路径。
const DEFAULT_PATH := "res://ui/text/game_text.tres"

static var _shared: GameText

## 局内货币的名称。
@export var currency_name: String
## 局内货币的图标；留空时界面只显示名称与数量。
@export var currency_icon: Texture2D
## 顶栏货币，参数依次为名称、数量。
@export var currency_amount_format: String

## 顶栏幕数，参数为幕序号（从 1 开始）。
@export var act_label_format: String
## 顶栏生命，参数依次为当前生命、最大生命。
@export var health_label_format: String
## 顶栏卡组张数，参数为张数。
@export var deck_label_format: String
## 顶栏崩解度，参数依次为百分比、已探索地点数、当前幕地点总数。
@export var decay_label_format: String

## 底部状态栏的默认提示。
@export var travel_hint: String
## 试图前往不可达地点时的提示。
@export var travel_rejected_message: String
## 进入新一幕时的提示，参数为幕序号（从 1 开始）。
@export var act_started_format: String

## 节点面板里进入下一幕的按钮文字。
@export var next_act_action: String
## 节点面板里返回地图的按钮文字。
@export var close_panel_action: String

## 序列符号在界面上的显示名。代码里是 `RED` / `BLUE` / `YI`，玩家看到什么字只取决于
## 这三个字段，改叫法只改这里。
@export var symbol_red_name: String
@export var symbol_blue_name: String
@export var symbol_yi_name: String
## 序列为空时的提示。
@export var sequence_empty_text: String


## 符号的显示名。没有配置时返回空串并报警告，避免把代码标识符泄露到界面上。
func symbol_name(symbol: CardSequence.Symbol) -> String:
	match symbol:
		CardSequence.Symbol.RED:
			return symbol_red_name
		CardSequence.Symbol.BLUE:
			return symbol_blue_name
		CardSequence.Symbol.YI:
			return symbol_yi_name
	push_warning("文案资源没有为符号 %d 配置显示名。" % symbol)
	return ""


## 取共享的文案资源。所有文案字段都没有脚本默认值，唯一来源是 [code]game_text.tres[/code]；
## 资源缺失时退回一份空实例并报警告，免得界面直接报错，但这时界面会缺文字。
static func shared() -> GameText:
	if _shared == null:
		_shared = load(DEFAULT_PATH) as GameText
	if _shared == null:
		push_warning("找不到文案资源 %s，界面文字会缺。" % DEFAULT_PATH)
		_shared = GameText.new()
	return _shared
