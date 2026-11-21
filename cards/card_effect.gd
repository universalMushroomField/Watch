## 卡牌效果的基类，具体效果由子类实现。
class_name CardEffect
extends Resource


## 执行卡牌效果。子类可读取战斗上下文并修改当前序列。
func apply(_sequence: CardSequence, _context: Dictionary) -> void:
	pass
