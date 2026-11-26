## 管理单场战斗的序列、手牌和各牌堆。
class_name CardManager
extends Node

signal hand_changed

## 当前回合的红蓝序列。
var sequence := CardSequence.new()
var effect_processor := EffectProcessor.new()
## 玩家战斗状态，敌人行动时也通过此对象结算伤害。
var player: Character
var _default_player: Character
var _turn_draw_count: int
var _sequence_carryover: int

## 抽牌堆，从数组末尾抽牌。
var draw_pile: Array[CardInstance] = []
## 当前持有的手牌，出牌时使用手牌下标选择。
var hand: Array[CardInstance] = []
## 弃牌堆，抽牌堆为空时可洗回。
var discard_pile: Array[CardInstance] = []
## 除外堆，其中的卡牌本场战斗不会被重新抽到。
var exhaust_pile: Array[CardInstance] = []


## 将卡组中的有效卡牌放入抽牌堆并洗牌。
func get_deck(deck: CardDeck, player_unit: Character = null) -> void:
	for pile in [draw_pile, hand, discard_pile, exhaust_pile]:
		for instance in pile:
			instance.queue_free()
		pile.clear()
	effect_processor.reset()
	sequence.clear()
	if player_unit == null:
		if _default_player == null:
			_default_player = Character.new()
			add_child(_default_player)
		_default_player.health = 1
		_default_player.armor = 0
		_default_player.clear_damage_blocks()
		player_unit = _default_player
	player = player_unit
	_turn_draw_count = deck.turn_draw_count
	sequence.max_length = deck.sequence_limit
	_sequence_carryover = deck.sequence_carryover
	for card in deck.cards:
		if card != null:
			var instance := CardInstance.new()
			instance.card = card
			add_child(instance)
			draw_pile.append(instance)
	draw_pile.shuffle()
	hand_changed.emit()


## 获取手牌数组的副本。
func get_hand() -> Array[CardInstance]:
	return hand.duplicate()


## 获取抽牌堆数组的副本。
func get_draw_pile() -> Array[CardInstance]:
	return draw_pile.duplicate()


## 获取弃牌堆数组的副本。
func get_discard_pile() -> Array[CardInstance]:
	return discard_pile.duplicate()


## 获取除外堆数组的副本。
func get_exhaust_pile() -> Array[CardInstance]:
	return exhaust_pile.duplicate()


## 抽取指定数量的卡牌并加入手牌，抽牌堆为空时洗入弃牌堆。
## 两堆均空时停止，返回实际抽到的卡牌。
func draw(count: int = 1) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for draw_index in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.assign(discard_pile)
			discard_pile.clear()
			draw_pile.shuffle()
		var card: CardInstance = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)
	if not drawn.is_empty():
		hand_changed.emit()
	return drawn


## 按角色配置抽取回合开始时的手牌。
func start_turn() -> Array[CardInstance]:
	if is_instance_valid(player):
		player.clear_damage_blocks()
	return draw(_turn_draw_count)


## 获取指定手牌可用的序列消耗位置。无费用时返回 [0]。
func get_play_positions(hand_index: int) -> Array[int]:
	if hand_index < 0 or hand_index >= hand.size():
		return []
	var card := hand[hand_index].card
	if card.cost_at_top or card.sequence_cost.is_empty():
		var positions: Array[int] = []
		if sequence.has_pattern_at_top(card.sequence_cost):
			positions.append(0)
		return positions
	return sequence.find_pattern_positions(card.sequence_cost)


## 检查手牌下标和序列消耗是否有效，序列位置为 -1 时选用第一个匹配。
func can_play(hand_index: int, sequence_start: int = -1) -> bool:
	return _resolve_play_position(hand_index, sequence_start) >= 0


## 将默认位置或显式位置解析为当前序列的有效下标。
func _resolve_play_position(hand_index: int, start: int) -> int:
	if hand_index < 0 or hand_index >= hand.size():
		return -1
	var card := hand[hand_index].card
	if start == -1:
		if card.cost_at_top or card.sequence_cost.is_empty():
			start = 0
		else:
			return sequence.find_first_pattern_position(card.sequence_cost)
	if card.cost_at_top and start != 0:
		return -1
	return start if sequence.can_consume(card.sequence_cost, start) else -1


## 消耗序列，加入红蓝符号并执行卡牌效果，最后将牌移入弃牌堆或除外堆。
## 序列位置为 -1 时消耗第一个匹配，校验失败时返回 false。
func play(hand_index: int, context: Dictionary = {}, sequence_start: int = -1) -> bool:
	var start := _resolve_play_position(hand_index, sequence_start)
	if start < 0:
		return false
	var instance := hand[hand_index]
	var card := instance.card
	var effect_context := context.duplicate()
	effect_context[&"player"] = player
	effect_context[&"card_manager"] = self
	if not EffectProcessor.can_apply(card.effects, effect_context):
		return false

	hand.remove_at(hand_index)
	sequence.consume(card.sequence_cost, start)
	sequence.insert_symbols(start, card.sequence_replacement)
	match card.kind:
		CardData.Kind.RED:
			sequence.push(CardSequence.Symbol.RED)
		CardData.Kind.BLUE:
			sequence.push(CardSequence.Symbol.BLUE)

	effect_processor.submit(card.effects, sequence, effect_context)

	# 先结算抽牌，避免本次打出的牌立即被弃牌堆洗回。
	if card.extra_draw > 0:
		draw(card.extra_draw)

	if card.exhaust_on_play:
		exhaust_pile.append(instance)
	else:
		discard_pile.append(instance)
	hand_changed.emit()
	return true


## 将指定手牌移入弃牌堆，下标无效时返回 false。
func discard(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	discard_pile.append(hand.pop_at(hand_index))
	hand_changed.emit()
	return true


## 将指定手牌移入除外堆，下标无效时返回 false。
func exhaust(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size():
		return false
	exhaust_pile.append(hand.pop_at(hand_index))
	hand_changed.emit()
	return true


## 将剩余手牌移入弃牌堆，并从序列顶清除超出继承长度的符号。
func end_turn() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	sequence.keep_tail(_sequence_carryover)
	hand_changed.emit()
