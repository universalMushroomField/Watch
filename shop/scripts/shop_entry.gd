## 商店里的一件商品。
class_name ShopEntry
extends Resource

## 出售的卡牌。
@export var card: CardData
## 售价，单位金币。
@export var price: int = 50
## 每次进入商店时的库存数量。
@export var stock: int = 1
