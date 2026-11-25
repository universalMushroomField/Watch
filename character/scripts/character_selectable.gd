extends Character

class_name CharacterSelectable

## 玩家的卡组，回合抽牌数与序列上限等数值随卡组资源一起配置。
@export var deck:CardDeck

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
