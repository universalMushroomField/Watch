## 管理单场战斗的序列、手牌和各牌堆。
class_name CardCombat
extends RefCounted

## 当前回合的攻防序列。
var sequence := CardSequence.new()

## 抽牌堆，从数组末尾抽牌。
var _draw_pile: Array[CardData] = []
## 当前持有的手牌，出牌时使用手牌下标选择。
var _hand: Array[CardData] = []
## 弃牌堆，抽牌堆为空时可洗回。
var _discard_pile: Array[CardData] = []
## 除外堆，其中的卡牌本场战斗不会被重新抽到。
var _exhaust_pile: Array[CardData] = []


## 将卡组中的有效卡牌放入抽牌堆并洗牌。
func _init(deck: CardDeck) -> void:
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


## 检查手牌下标和序列消耗是否有效，序列位置为 -1 时检查任意位置。
func can_play(hand_index: int, sequence_start: int = -1) -> bool:
	return (
		hand_index >= 0
		and hand_index < _hand.size()
		and sequence.can_consume(_hand[hand_index].sequence_cost, sequence_start)
	)


## 消耗序列，加入攻防符号并执行卡牌效果，最后将牌移入弃牌堆或除外堆。
## 序列位置为 -1 时消耗第一个匹配，校验失败时返回 false。
func play(hand_index: int, context: Dictionary = {}, sequence_start: int = -1) -> bool:
	if not can_play(hand_index, sequence_start):
		return false

	var card: CardData = _hand.pop_at(hand_index)
	sequence.consume(card.sequence_cost, sequence_start)
	match card.kind:
		CardData.Kind.ATTACK:
			sequence.push(CardSequence.Symbol.ATTACK)
		CardData.Kind.DEFENSE:
			sequence.push(CardSequence.Symbol.DEFENSE)

	for effect in card.effects:
		if effect != null:
			effect.apply(sequence, context)

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
