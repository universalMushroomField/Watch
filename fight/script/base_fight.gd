## 战斗场景的回合流程。
class_name BaseFight
extends Node2D

const CARD_VIEW := preload("res://cards/templates/sprite_tscn/default_card_sprite.tscn")

@export var card_manager: CardManager
@export var player_character: CharacterSelectable
## 敌人按数组顺序行动。
@export var enemies: Array[Enemy] = []

@export var fight_ui: Control

## 敌人的定位位置
@export var enemy_pos: Node2D
## 玩家的定位位置
@export var player_pos: Node2D
## 相邻敌人精灵中心之间的水平间距。
@export_range(0.0, 1024.0, 1.0, "or_greater") var enemy_spacing: float = 140.0

var round_count: int = 0
var cur_stage: BattlePhase.Stage = BattlePhase.Stage.START


func _ready() -> void:
	if fight_ui != null:
		var end_button := fight_ui.get_node_or_null("OverRoundButton") as Button
		if end_button != null:
			end_button.pressed.connect(end_player_turn)
	if player_character != null:
		start_fight(player_character)


func start_fight(player: CharacterSelectable) -> bool:
	if cur_stage != BattlePhase.Stage.START or player == null or player.deck == null or card_manager == null:
		return false
	player_character = player
	prepare()
	card_manager.hand_changed.connect(_refresh_hand)
	card_manager.get_deck(player.deck, player)
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.reset_action_state()
	if fight_ui is FightingGui:
		fight_ui.bind_fight(self)
	if fight_ui != null:
		fight_ui.show()
	_enter_stage(BattlePhase.Stage.START)
	_begin_player_turn()
	return true


## 玩家放在玩家锚点，敌人从最右侧锚点向左排开。
func prepare() -> void:
	if is_instance_valid(player_character) and is_instance_valid(player_character.sprite) and is_instance_valid(player_pos):
		player_character.sprite.global_position = player_pos.global_position

	if not is_instance_valid(enemy_pos):
		return
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if not is_instance_valid(enemy) or not is_instance_valid(enemy.sprite):
			continue
		var offset := Vector2((index - enemies.size() + 1) * enemy_spacing, 0.0)
		enemy.sprite.global_position = enemy_pos.to_global(offset)


func _refresh_hand() -> void:
	if fight_ui == null:
		return
	var hand_container := fight_ui.get_node_or_null("%HandContainer") as HBoxContainer
	if hand_container == null:
		return
	for view in hand_container.get_children():
		hand_container.remove_child(view)
		view.queue_free()
	for instance in card_manager.hand:
		var view := CARD_VIEW.instantiate() as CardView
		view.show_card(instance.card)
		view.hand_card = instance
		hand_container.add_child(view)


func end_player_turn() -> void:
	if cur_stage != BattlePhase.Stage.PLAYER:
		return
	if fight_ui is FightingGui:
		fight_ui.cancel_play()
	_enter_stage(BattlePhase.Stage.END)
	if _finish_if_decided():
		return
	card_manager.end_turn()
	_enter_stage(BattlePhase.Stage.ENEMYTURN)
	if _finish_if_decided():
		return
	for enemy in enemies.duplicate():
		if not is_instance_valid(player_character) or player_character.health <= 0:
			break
		if is_instance_valid(enemy):
			enemy.take_turn(player_character, card_manager.sequence, card_manager.effect_processor)
	_begin_player_turn()


func play_card(instance: CardInstance, target: Enemy, sequence_start: int) -> bool:
	if cur_stage != BattlePhase.Stage.PLAYER or not is_instance_valid(instance):
		return false
	if instance.card.requires_target():
		if not is_instance_valid(target) or target.health <= 0 or not enemies.has(target):
			return false
	var living_enemies: Array[Enemy] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			living_enemies.append(enemy)
	var context := {&"target": target, &"enemies": living_enemies}
	if not card_manager.play(card_manager.hand.find(instance), context, sequence_start):
		return false
	_finish_if_decided()
	return true


func _begin_player_turn() -> void:
	if _finish_if_decided():
		return
	_enter_stage(BattlePhase.Stage.DRAW)
	if _finish_if_decided():
		return
	round_count += 1
	card_manager.start_turn()
	if fight_ui != null:
		var round_label := fight_ui.get_node_or_null("RoundCount") as Label
		if round_label != null:
			round_label.text = "回合数 %d" % round_count
	_enter_stage(BattlePhase.Stage.PLAYER)
	_finish_if_decided()


func _finish_if_decided() -> bool:
	if is_instance_valid(player_character) and player_character.health > 0 and _has_living_enemy():
		return false
	_enter_stage(BattlePhase.Stage.FINISHED)
	return true


func _enter_stage(next_stage: BattlePhase.Stage) -> void:
	cur_stage = next_stage
	card_manager.effect_processor.enter_stage(next_stage)


func _has_living_enemy() -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.health > 0:
			return true
	return false
