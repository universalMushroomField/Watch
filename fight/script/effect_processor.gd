class_name EffectProcessor
extends RefCounted

var _pending: Array[EffectInstance] = []
var _stage: BattlePhase.Stage = BattlePhase.Stage.START
var _draining := false


static func can_apply(effects: Array[Effect], context: Dictionary) -> bool:
	for effect in effects:
		if effect != null and not effect.can_apply(context):
			return false
	return true


func reset() -> void:
	_pending.clear()
	_stage = BattlePhase.Stage.START


func enter_stage(stage: BattlePhase.Stage) -> void:
	_stage = stage
	_drain()


## 按配置顺序计算效果。立即效果当场执行，阶段效果按提交顺序排队。
func submit(effects: Array[Effect], sequence: CardSequence, context: Dictionary) -> void:
	for effect in effects:
		if effect == null:
			continue
		var prepared_effect := effect.duplicate() as Effect
		var operation := prepared_effect.prepare(sequence, context.duplicate())
		if effect.immediate:
			operation.call()
		else:
			_pending.append(EffectInstance.new(effect.effective_stage, operation, prepared_effect))
	_drain()


func process_effects(effects: Array[Effect], sequence: CardSequence, context: Dictionary) -> bool:
	if not can_apply(effects, context):
		return false
	submit(effects, sequence, context)
	return true


func _drain() -> void:
	if _draining:
		return
	_draining = true
	while true:
		var index := _pending.find_custom(func(instance: EffectInstance) -> bool: return instance.stage == _stage)
		if index < 0:
			break
		var instance: EffectInstance = _pending.pop_at(index)
		instance.execute.call()
	_draining = false
