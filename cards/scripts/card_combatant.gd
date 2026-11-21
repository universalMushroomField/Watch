## 卡牌战斗中可承受伤害和获得护甲的单位。
class_name CardCombatant
extends RefCounted

var health: int
var armor: int = 0
var _blocked_sources: Array[CardCombatant] = []


func _init(initial_health: int = 1) -> void:
	health = maxi(initial_health, 0)


## 承受来自指定单位的伤害，返回实际损失的生命值。
func take_damage(amount: int, source: CardCombatant = null) -> int:
	if amount <= 0 or health == 0:
		return 0
	var blocked := _blocked_sources.find(source)
	if blocked >= 0:
		_blocked_sources.remove_at(blocked)
		return 0
	var absorbed := mini(armor, amount)
	armor -= absorbed
	var lost := mini(health, amount - absorbed)
	health -= lost
	return lost


## 令指定敌人的下一次伤害无效。
func block_next_damage_from(source: CardCombatant) -> void:
	_blocked_sources.append(source)


## 清除上一回合剩余的伤害无效次数。
func clear_damage_blocks() -> void:
	_blocked_sources.clear()
