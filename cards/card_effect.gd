## 卡牌效果的基类，具体效果由子类实现。
class_name CardEffect
extends Resource


## 检查结算所需的目标和战斗上下文。
func can_apply(_context: Dictionary) -> bool:
	return true


## 执行卡牌效果。子类可读取战斗上下文并修改当前序列。
func apply(_sequence: CardSequence, _context: Dictionary) -> void:
	pass
