## 为出牌角色增加护甲。
class_name ArmorEffect
extends Effect

@export var amount: int = 0


func can_apply(context: Dictionary) -> bool:
	return context.get(&"player") is Character


func apply(_sequence: CardSequence, context: Dictionary) -> void:
	var player: Character = context[&"player"]
	if is_instance_valid(player):
		player.armor += amount
