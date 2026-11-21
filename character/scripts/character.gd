## 最基本的角色类

extends Node
class_name Character
@export var character_id:String;
@export var character_name:String;
@export var life_count:int =10;

signal died(character: Character)

func take_damage(amount: int) -> void:
	if life_count <= 0:
		return
		
	life_count = max(0, life_count - amount)
	if life_count == 0:
		_on_death()

func _on_death() -> void:
	died.emit(self)
