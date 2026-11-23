## 效果的基类，具体效果由子类实现。
class_name Effect
extends Resource

@export var immediate: bool = true
@export var effective_stage: BattlePhase.Stage = BattlePhase.Stage.END


## 提交时计算效果，并返回供指定阶段执行的操作。
func prepare(sequence: CardSequence, context: Dictionary) -> Callable:
	return apply.bind(sequence, context)


## 是否需要玩家指定单个目标。
func requires_target() -> bool:
	return false


## 检查结算所需的目标和战斗上下文。
func can_apply(_context: Dictionary) -> bool:
	return true


## 执行效果。子类可读取战斗上下文并修改当前序列。
func apply(_sequence: CardSequence, _context: Dictionary) -> void:
	pass
