## 保存角色当前卡组和可获得的奖励卡池。
class_name CardDeck
extends Resource

## 回合开始时的抽牌数量。
@export var turn_draw_count: int = 0
## 战斗的序列长度上限，-1 表示不限。
@export var sequence_limit: int = -1

## 进入战斗时使用的卡牌列表，允许同一张牌出现多次。
@export var cards: Array[CardData] = []
## 所选角色可获得的奖励卡牌。
@export var reward_pool: Array[CardData] = []


## 将卡池中的奖励牌加入卡组，空资源或卡池外的牌会返回 false。
func add_reward(card: CardData) -> bool:
	if card == null or not reward_pool.has(card):
		return false
	cards.append(card)
	return true
