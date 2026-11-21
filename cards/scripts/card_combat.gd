## 管理单场战斗的序列、手牌和各牌堆。
class_name CardCombat
extends RefCounted

## 当前回合的攻防序列。
var sequence := CardSequence.new()
## 玩家战斗状态，敌人行动时也通过此对象结算伤害。
var player: CardCombatant
var _turn_draw_count: int

## 抽牌堆，从数组末尾抽牌。
var _draw_pile: Array[CardData] = []
## 当前持有的手牌，出牌时使用手牌下标选择。
var _hand: Array[CardData] = []
## 弃牌堆，抽牌堆为空时可洗回。
var _discard_pile: Array[CardData] = []
## 除外堆，其中的卡牌本场战斗不会被重新抽到。
var _exhaust_pile: Array[CardData] = []


## 将卡组中的有效卡牌放入抽牌堆并洗牌。
func _init(deck: CardDeck, player_unit: CardCombatant = null) -> void:
	player = player_unit if player_unit != null else CardCombatant.new()
	_turn_draw_count = deck.turn_draw_count
	sequence.max_length = deck.sequence_limit
	for card in deck.cards:
		if card != null:
			_draw_pile.append(card)
	_draw_pile.shuffle()


## 获取手牌数组的副本。
func get_hand() -> Array[CardData]:
	return _hand.duplicate()


## 获取抽牌堆数组的副本。
func get_draw_pile() -> Array[CardData]:
	return _draw_pile.duplicate()


## 获取弃牌堆数组的副本。
func get_discard_pile() -> Array[CardData]:
	return _discard_pile.duplicate()


## 获取除外堆数组的副本。
func get_exhaust_pile() -> Array[CardData]:
	return _exhaust_pile.duplicate()


## 抽取指定数量的卡牌并加入手牌，抽牌堆为空时洗入弃牌堆。
## 两堆均空时停止，返回实际抽到的卡牌。
func draw(count: int = 1) -> Array[CardData]:
	var drawn: Array[CardData] = []
	for draw_index in range(count):
		if _draw_pile.is_empty():
			if _discard_pile.is_empty():
				break
			_draw_pile.assign(_discard_pile)
			_discard_pile.clear()
			_draw_pile.shuffle()
		var card: CardData = _draw_pile.pop_back()
		_hand.append(card)
		drawn.append(card)
	return drawn


## 按角色配置抽取回合开始时的手牌。
func start_turn() -> Array[CardData]:
	player.clear_damage_blocks()
	return draw(_turn_draw_count)


## 获取指定手牌可用的序列消耗位置。无费用时返回 [0]。
func get_play_positions(hand_index: int) -> Array[int]:
	if hand_index < 0 or hand_index >= _hand.size():
		return []
	var card := _hand[hand_index]
	if card.cost_at_top or card.sequence_cost.is_empty():
		return [0] if sequence.has_pattern_at_top(card.sequence_cost) else []
	return sequence.find_pattern_positions(card.sequence_cost)


## 检查手牌下标和序列消耗是否有效，序列位置为 -1 时选用第一个匹配。
func can_play(hand_index: int, sequence_start: int = -1) -> bool:
	return _resolve_play_position(hand_index, sequence_start) >= 0


## 将默认位置或显式位置解析为当前序列的有效下标。
func _resolve_play_position(hand_index: int, start: int) -> int:
	if hand_index < 0 or hand_index >= _hand.size():
		return -1
	var card := _hand[hand_index]
	if start == -1:
		if card.cost_at_top or card.sequence_cost.is_empty():
			start = 0
		else:
			return sequence.find_first_pattern_position(card.sequence_cost)
	if card.cost_at_top and start != 0:
		return -1
	return start if sequence.can_consume(card.sequence_cost, start) else -1


## 消耗序列，加入攻防符号并执行卡牌效果，最后将牌移入弃牌堆或除外堆。
## 序列位置为 -1 时消耗第一个匹配，校验失败时返回 false。
func play(hand_index: int, context: Dictionary = {}, sequence_start: int = -1) -> bool:
	var start := _resolve_play_position(hand_index, sequence_start)
	if start < 0:
		return false
	var card := _hand[hand_index]
	var effect_context := context.duplicate()
	effect_context[&"player"] = player
	for effect in card.effects:
		if effect != null and not effect.can_apply(effect_context if effect is CombatCardEffect else context):
			return false

	_hand.remove_at(hand_index)
	sequence.consume(card.sequence_cost, start)
	sequence.insert_symbols(start, card.sequence_replacement)
	match card.kind:
		CardData.Kind.ATTACK:
			sequence.push(CardSequence.Symbol.ATTACK)
		CardData.Kind.DEFENSE:
			sequence.push(CardSequence.Symbol.DEFENSE)

	for effect in card.effects:
		if effect != null:
			effect.apply(sequence, effect_context if effect is CombatCardEffect else context)

	# 先结算抽牌，避免本次打出的牌立即被弃牌堆洗回。
	if card.extra_draw > 0:
		draw(card.extra_draw)

	if card.exhaust_on_play:
		_exhaust_pile.append(card)
	else:
		_discard_pile.append(card)
	return true


## 将指定手牌移入弃牌堆，下标无效时返回 false。
func discard(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= _hand.size():
		return false
	_discard_pile.append(_hand.pop_at(hand_index))
	return true


## 将指定手牌移入除外堆，下标无效时返回 false。
func exhaust(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= _hand.size():
		return false
	_exhaust_pile.append(_hand.pop_at(hand_index))
	return true


## 将剩余手牌移入弃牌堆并清空回合序列。
func end_turn() -> void:
	_discard_pile.append_array(_hand)
	_hand.clear()
	sequence.clear()
