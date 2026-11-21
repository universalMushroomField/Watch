## 发牌员类，初始化方式为接收一个deck将其填充入抽卡堆，
## 功能为在发牌阶段发牌，在牌被打出时将牌放入指定堆
extends Node
class_name CardManager
##抽卡堆
var draw_pile:Array[CardInstance]
##手牌堆
var hand:Array[CardInstance]
#墓地区/弃牌堆/随你怎么叫罢牌佬
##弃牌堆
var discard_pile:Array[CardInstance]
##除外堆
var exhaust_pile:Array[CardInstance]
func _ready() -> void:
	pass
##从carddeck获取牌,放入抽牌堆
func get_deck(deck:CardDeck):
	pass
	
