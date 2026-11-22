## 抵消指定敌人对出牌角色的下一次伤害。
class_name BlockNextDamageEffect
extends Effect


func requires_target() -> bool:
	return true


func can_apply(context: Dictionary) -> bool:
	var target = context.get(&"target")
	return context.get(&"player") is Character and target is Character and target.life_count > 0


func apply(_sequence: CardSequence, context: Dictionary) -> void:
	var player: Character = context[&"player"]
	var target: Character = context[&"target"]
	if is_instance_valid(player) and is_instance_valid(target):
		player.block_next_damage_from(target)
