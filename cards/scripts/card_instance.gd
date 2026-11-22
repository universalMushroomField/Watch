@tool
## 卡牌实例场景保存卡牌定义，可由场景加载器读取。
class_name CardInstance
extends Control

@export var card: CardData:
	set(value):
		if Engine.is_editor_hint() and card != null and card.changed.is_connected(_refresh_card_face):
			card.changed.disconnect(_refresh_card_face)
		card = value
		if is_node_ready():
			_watch_card()
			_refresh_card_face()

@export var sprite: Control:
	set(value):
		sprite = value
		if is_node_ready():
			_refresh_card_face()


func _ready() -> void:
	_watch_card()
	_refresh_card_face()


func _watch_card() -> void:
	if Engine.is_editor_hint() and card != null and not card.changed.is_connected(_refresh_card_face):
		card.changed.connect(_refresh_card_face)


func _refresh_card_face() -> void:
	if sprite is CardView:
		sprite.show_card(card)
