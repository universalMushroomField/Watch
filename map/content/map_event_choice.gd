## 未知事件里的一个选项，结算金币、生命和生命上限的变化。
class_name MapEventChoice
extends Resource

## 选项按钮上的文字。
@export var label: String = "继续"
## 结算后显示的说明。
@export_multiline var result_text: String = ""
## 金币变化，负数表示失去金币。
@export var gold_delta: int = 0
## 生命变化，负数表示失去生命。
@export var health_delta: int = 0
## 生命上限变化。
@export var max_health_delta: int = 0


## 把选项结果结算到玩家状态。
func apply(player: MapPlayerState) -> void:
	if player == null:
		return
	if max_health_delta != 0:
		player.change_max_health(max_health_delta)
	if gold_delta != 0:
		player.add_gold(gold_delta)
	if health_delta > 0:
		player.heal(health_delta)
	elif health_delta < 0:
		player.lose_health(-health_delta)
