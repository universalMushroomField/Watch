## 战斗场景的基类实现

extends Node2D

class_name BaseFightScene

##玩家角色
@export var player_character:CharacterSelectable

##卡牌管理器（发牌员（
@export var card_manager:CardManager

##enemies 从array头到尾轮流行动
@export var enemies:Array[Character] = []

##GUI 
@export var fight_ui:Control

#回合数
var round_count:int =0

#回合的阶段
enum stage{
	START,
	DRAW,
	PLAYER,
	END,  
	ENEMYTURN,
}
var cur_stage:stage =stage.START

func _ready() -> void:
	pass
	
##在回合的阶段间切换，回合数控制
func _process(delta: float) -> void:
	pass
