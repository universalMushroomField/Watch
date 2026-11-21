extends Character

class_name CharacterSelectable

## 玩家的卡组
@export var deck:CardDeck
## 回合开始时的抽牌数量。
@export var turn_draw_count: int = 0
## 战斗的序列长度上限，-1 表示不限。
@export var sequence_limit: int = -1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
