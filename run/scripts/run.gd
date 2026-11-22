## 单局管理器类，持有种子，地图，玩家等等
extends Node2D
@onready var run_seed;
# Called when the node enters the scene tree for the first time.
@export var fight_system:BaseFightScene
##玩家角色
@export var player_character:CharacterSelectable
func _ready() -> void:

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

##从存档读取单局

##初始化单局
