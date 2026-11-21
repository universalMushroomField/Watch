## 战斗场景的基类实现

extends Node2D

class_name BaseFightScene

#玩家
@export var player:Node

#enemies从头到尾轮流行动
@export var enemies:Array[Node] = []

#GUI 
@export var fight_ui:Control

#回合数
var round_count:int =0

#回合的阶段
enum stage{
	PLAYER = 0,
	ENEMY  = 1
}
var cur_stage:stage =stage.PLAYER

func _ready() -> void:
	pass
