## 商店库存：可购买的卡牌和一次治疗服务。
class_name ShopStockData
extends Resource

## 在售卡牌。
@export var entries: Array[ShopEntry] = []
## 治疗服务的价格。
@export var heal_price: int = 30
## 治疗服务恢复的生命值。
@export var heal_amount: int = 20
