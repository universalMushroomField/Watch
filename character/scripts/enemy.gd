class_name Enemy
extends Character

@export var action_states: Array[EnemyActionState] = []
@export var initial_state: int = 0

const INTENT_VIEW := preload("res://ui/character/enemy_intent.tscn")

var _intent_view: Label
var current_state: int = 0:
	set(value):
		current_state = value
		_refresh_intent()


func _ready() -> void:
	super._ready()
	if sprite != null:
		_intent_view = INTENT_VIEW.instantiate() as Label
		sprite.add_child(_intent_view)
		sprite.frame_changed.connect(_refresh_intent)
		died.connect(_hide_intent)
	reset_action_state()


func reset_action_state() -> void:
	current_state = initial_state


func _refresh_intent() -> void:
	if _intent_view == null:
		return
	var text := ""
	if life_count > 0 and current_state >= 0 and current_state < action_states.size():
		var action := action_states[current_state]
		if action != null:
			text = action.intent_text
	_intent_view.text = text
	_intent_view.visible = not text.is_empty()
	_intent_view.reset_size()
	var bounds := _sprite_bounds()
	_intent_view.position = Vector2(
		bounds.get_center().x - _intent_view.size.x * 0.5,
		bounds.position.y - _intent_view.size.y - 8.0
	)


func _hide_intent(_character: Character) -> void:
	_intent_view.hide()


## 每个敌方回合只结算一次行动，成功后切换到后继状态。
func take_turn(target: Character, sequence: CardSequence) -> bool:
	if life_count <= 0 or not is_instance_valid(target) or target.life_count <= 0:
		return false
	if current_state < 0 or current_state >= action_states.size():
		return false
	var action := action_states[current_state]
	if action == null or action.next_state < 0 or action.next_state >= action_states.size():
		return false
	var context := {&"player": self, &"target": target, &"enemies": [target]}
	if not EffectProcessor.process_effects(action.effects, sequence, context):
		return false
	current_state = action.next_state
	return true
