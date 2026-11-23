## 一次已计算的效果，保存提交时的阶段和结算操作。
class_name EffectInstance
extends RefCounted

var stage: BattlePhase.Stage
var execute: Callable
var _effect: Effect


func _init(target_stage: BattlePhase.Stage, operation: Callable, effect: Effect) -> void:
	stage = target_stage
	execute = operation
	_effect = effect
