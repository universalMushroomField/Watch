class_name CardDeck
extends Resource
## Persistent deck composition. The reward pool belongs to the chosen character.

@export var cards: Array[CardData] = []
@export var reward_pool: Array[CardData] = []


func add_reward(card: CardData) -> bool:
	if card == null or not reward_pool.has(card):
		return false
	cards.append(card)
	return true
