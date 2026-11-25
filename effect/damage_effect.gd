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
	return target is Character and target.health > 0


func prepare(_sequence: CardSequence, context: Dictionary) -> Callable:
	var source := context.get(&"player") as Character
	var targets: Array = context[&"enemies"] if all_enemies else [context[&"target"]]
	var hits: Array[Callable] = []
	for target in targets:
		if target is Character:
			var damage: int = target.prepare_damage(amount, source)
			if damage > 0:
				hits.append(target.apply_resolved_damage.bind(damage))
	return func() -> void:
		for hit in hits:
			if hit.is_valid():
				hit.call()
