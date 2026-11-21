class_name CardCombat
extends RefCounted

var sequence := CardSequence.new()

var _draw_pile: Array[CardData] = []
var _hand: Array[CardData] = []
var _discard_pile: Array[CardData] = []
var _exhaust_pile: Array[CardData] = []


func _init(deck: CardDeck) -> void:
	for card in deck.cards:
		if card != null:
			_draw_pile.append(card)
	_draw_pile.shuffle()


func get_hand() -> Array[CardData]:
	return _hand.duplicate()


func get_draw_pile() -> Array[CardData]:
	return _draw_pile.duplicate()


func get_discard_pile() -> Array[CardData]:
	return _discard_pile.duplicate()


func get_exhaust_pile() -> Array[CardData]:
	return _exhaust_pile.duplicate()


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


func can_play(hand_index: int, sequence_start: int = -1) -> bool:
	return (
		hand_index >= 0
		and hand_index < _hand.size()
		and sequence.can_consume(_hand[hand_index].sequence_cost, sequence_start)
	)


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


func discard(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= _hand.size():
		return false
	_discard_pile.append(_hand.pop_at(hand_index))
	return true


func exhaust(hand_index: int) -> bool:
	if hand_index < 0 or hand_index >= _hand.size():
		return false
	_exhaust_pile.append(_hand.pop_at(hand_index))
	return true


func end_turn() -> void:
	_discard_pile.append_array(_hand)
	_hand.clear()
	sequence.clear()
