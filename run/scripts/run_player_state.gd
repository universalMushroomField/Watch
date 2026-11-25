## 一局游戏中随地图推进的玩家状态：生命、金币和卡组。
class_name RunPlayerState
extends RefCounted

## 生命上限。
var max_health: int
## 当前生命。
var health: int
## 当前金币。
var gold: int
## 本局使用的卡组，从角色配置复制而来。
var deck: CardDeck


func _init(initial_max_health: int = 70, starting_gold: int = 50, starting_deck: CardDeck = null) -> void:
	max_health = maxi(initial_max_health, 1)
	health = max_health
	gold = maxi(starting_gold, 0)
	deck = CardDeck.new()
	if starting_deck != null:
		deck.turn_draw_count = starting_deck.turn_draw_count
		deck.sequence_limit = starting_deck.sequence_limit
		deck.sequence_carryover = starting_deck.sequence_carryover
		deck.cards.assign(starting_deck.cards)
		deck.reward_pool.assign(starting_deck.reward_pool)


## 恢复生命，返回实际恢复量。
func heal(amount: int) -> int:
	if amount <= 0:
		return 0
	var healed := mini(amount, max_health - health)
	health += healed
	return healed


## 失去生命，返回实际损失量。
func lose_health(amount: int) -> int:
	if amount <= 0:
		return 0
	var lost := mini(amount, health)
	health -= lost
	return lost


## 改变生命上限，当前生命不会超过新的上限。
func change_max_health(delta: int) -> void:
	max_health = maxi(max_health + delta, 1)
	health = mini(health, max_health)


## 增加或扣除金币，金币不会低于 0。
func add_gold(amount: int) -> void:
	gold = maxi(gold + amount, 0)


## 支付金币，金币不足时返回 false。
func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	return true


## 把一张牌加入本局卡组。
func add_card(card: CardData) -> bool:
	if card == null:
		return false
	deck.cards.append(card)
	return true


## 当前卡组张数。
func get_deck_size() -> int:
	return deck.cards.size()
