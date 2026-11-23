## 通过战斗中的卡牌管理器抽牌。
class_name DrawCardsEffect
extends Effect

@export var count: int = 0


func can_apply(context: Dictionary) -> bool:
	return context.get(&"card_manager") is CardManager


func apply(_sequence: CardSequence, context: Dictionary) -> void:
	var card_manager: CardManager = context[&"card_manager"]
	if is_instance_valid(card_manager):
		card_manager.draw(count)
