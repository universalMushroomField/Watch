## 人物 A 使用的伤害、护甲和伤害无效效果。
class_name CombatCardEffect
extends CardEffect

enum Operation { DAMAGE, DAMAGE_ALL, ARMOR, BLOCK_NEXT_DAMAGE }

@export var operation: Operation
@export var amount: int = 0


## 单体效果需要存活的目标，群攻需要传入敌人列表。
func can_apply(context: Dictionary) -> bool:
	match operation:
		Operation.DAMAGE, Operation.BLOCK_NEXT_DAMAGE:
			var target = context.get(&"target")
			return target is CardCombatant and target.health > 0
		Operation.DAMAGE_ALL:
			return context.get(&"enemies") is Array
	return true


## target 为选中的敌人，enemies 为群攻目标列表。
func apply(_sequence: CardSequence, context: Dictionary) -> void:
	var player: CardCombatant = context[&"player"]
	match operation:
		Operation.DAMAGE:
			var target: CardCombatant = context[&"target"]
			target.take_damage(amount, player)
		Operation.DAMAGE_ALL:
			for enemy in context[&"enemies"]:
				if enemy is CardCombatant:
					enemy.take_damage(amount, player)
		Operation.ARMOR:
			player.armor += amount
		Operation.BLOCK_NEXT_DAMAGE:
			player.block_next_damage_from(context[&"target"])
