## 按配置顺序结算效果，目标校验在任何效果执行之前完成。
class_name EffectProcessor
extends Node


static func can_apply(effects: Array[Effect], context: Dictionary) -> bool:
	for effect in effects:
		if effect != null and not effect.can_apply(context):
			return false
	return true


## 执行已通过校验的效果。出牌流程可在校验和结算之间支付费用。
static func apply(effects: Array[Effect], sequence: CardSequence, context: Dictionary) -> void:
	for effect in effects:
		if effect != null:
			effect.apply(sequence, context)


## 直接结算不涉及出牌费用的效果。
static func process_effects(effects: Array[Effect], sequence: CardSequence, context: Dictionary) -> bool:
	if not can_apply(effects, context):
		return false
	apply(effects, sequence, context)
	return true
