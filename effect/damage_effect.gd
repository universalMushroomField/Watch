## 对选中敌人或敌人列表造成伤害。
class_name DamageEffect
extends Effect

@export var amount: int = 0
@export var all_enemies: bool = false


func requires_target() -> bool:
	return not all_enemies


func can_apply(context: Dictionary) -> bool:
	if all_enemies:
		return context.get(&"enemies") is Array
	var target = context.get(&"target")
	return target is Character and target.life_count > 0


func apply(_sequence: CardSequence, context: Dictionary) -> void:
	var source := context.get(&"player") as Character
	if all_enemies:
		for enemy in context[&"enemies"]:
			if enemy is Character:
				enemy.take_damage(amount, source)
	else:
		var target: Character = context[&"target"]
		if is_instance_valid(target):
			target.take_damage(amount, source)
