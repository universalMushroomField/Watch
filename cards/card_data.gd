## 可在编辑器中配置的卡牌定义，同一份资源可在卡组中重复使用。
class_name CardData
extends Resource

## 卡牌类型，决定打出时是否向序列顶加入攻防符号。
enum Kind { ATTACK, DEFENSE, SPECIAL }

## 卡牌标识。
@export var id: StringName
## 界面上显示的卡牌名称。
@export var display_name: String
## 界面上显示的卡牌说明。
@export_multiline var description: String
## 这张牌所属的类型。
@export var kind: Kind = Kind.SPECIAL
## 出牌时消耗的连续子序列，按从序列顶到序列尾的方向填写。
@export var sequence_cost: Array[CardSequence.Symbol] = []
## 启用后，卡牌打出并结算完效果后进入除外堆。
@export var exhaust_on_play: bool = false
## 打出时按数组顺序执行的卡牌效果。
@export var effects: Array[CardEffect] = []
