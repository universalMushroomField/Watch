class_name FightingGUI
extends Control

const CARD_VIEW := preload("res://cards/templates/sprite_tscn/default_card_sprite.tscn")

@export_range(1, 20, 1, "or_greater") var cards_per_row: int = 6

var card_manager: CardManager
var _fight: BaseFightScene
var _pending_card: CardInstance
var _pending_target: Enemy
var _selected_start := -1
var _selected_count := 0

@onready var _play_zone: Control = %PlayZone
@onready var _sequence: SequenceSelector = %SequenceSelector
@onready var _play_hint: Label = %PlayHint
@onready var _cancel_button: Button = %CancelPlay

@onready var pile_view: Control = $PileView
@onready var pile_title: Label = %PileTitle
@onready var pile_scroll: ScrollContainer = %PileScroll
@onready var pile_grid: GridContainer = %PileGrid
@onready var empty_message: Label = %EmptyMessage


func _ready() -> void:
	$DrawButton.pressed.connect(_show_draw_pile)
	$DiscardButton.pressed.connect(_show_discard_pile)
	$ExhaustButton.pressed.connect(_show_exhaust_pile)
	%ClosePile.pressed.connect(pile_view.hide)
	_cancel_button.pressed.connect(cancel_play)
	_sequence.position_selected.connect(_select_sequence_position)


func _show_draw_pile() -> void:
	if is_instance_valid(card_manager):
		_show_pile($DrawButton.text, card_manager.get_draw_pile())


func _show_discard_pile() -> void:
	if is_instance_valid(card_manager):
		_show_pile($DiscardButton.text, card_manager.get_discard_pile())


func _show_exhaust_pile() -> void:
	if is_instance_valid(card_manager):
		_show_pile($ExhaustButton.text, card_manager.get_exhaust_pile())


func _show_pile(title: String, cards: Array[CardInstance]) -> void:
	for view in pile_grid.get_children():
		pile_grid.remove_child(view)
		view.queue_free()
	# 各牌堆的读取方法返回副本，浏览顺序独立于战斗顺序。
	cards.shuffle()
	pile_grid.columns = maxi(1, cards_per_row)
	for instance in cards:
		var view := CARD_VIEW.instantiate() as CardView
		view.show_card(instance.card)
		view.set_process(false)
		pile_grid.add_child(view)
	pile_title.text = title
	empty_message.visible = cards.is_empty()
	pile_scroll.visible = not cards.is_empty()
	pile_view.show()
	pile_scroll.scroll_vertical = 0
	pile_scroll.scroll_horizontal = 0


func bind_fight(fight: BaseFightScene) -> void:
	_fight = fight
	card_manager = fight.card_manager
	card_manager.sequence.changed.connect(_refresh_sequence)
	card_manager.hand_changed.connect(_on_hand_changed)
	_refresh_sequence()


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is CardInstance or not is_instance_valid(_fight) or pile_view.visible:
		return false
	if _fight.cur_stage != BattlePhase.Stage.PLAYER or is_instance_valid(_pending_card):
		return false
	if not card_manager.hand.has(data):
		return false
	var viewport_position := get_global_transform_with_canvas() * at_position
	if data.card.requires_target():
		return _enemy_at(viewport_position) != null
	return Rect2(Vector2.ZERO, _play_zone.size).has_point(
		_play_zone.get_global_transform_with_canvas().affine_inverse() * viewport_position
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var target: Enemy
	if data.card.requires_target():
		target = _enemy_at(get_global_transform_with_canvas() * at_position)
	var starts := card_manager.get_play_positions(card_manager.hand.find(data))
	if starts.is_empty():
		_play_hint.text = "当前序列无法支付这张牌"
		return
	if data.card.sequence_cost.is_empty():
		_commit_play(data, target, 0)
		return
	_pending_card = data
	_pending_target = target
	_cancel_button.show()
	_refresh_sequence()


func _enemy_at(viewport_position: Vector2) -> Enemy:
	for index in range(_fight.enemies.size() - 1, -1, -1):
		var enemy := _fight.enemies[index]
		if is_instance_valid(enemy) and enemy.life_count > 0 and enemy.has_sprite_at(viewport_position):
			return enemy
	return null


func _select_sequence_position(index: int) -> void:
	if not is_instance_valid(_pending_card):
		return
	var starts := card_manager.get_play_positions(card_manager.hand.find(_pending_card))
	if _selected_start < 0:
		if index not in starts:
			return
		_selected_start = index
	elif index != _selected_start + _selected_count or _selected_start not in starts:
		return
	_selected_count += 1
	if _selected_count == _pending_card.card.sequence_cost.size():
		var card := _pending_card
		var target := _pending_target
		var start := _selected_start
		cancel_play()
		_commit_play(card, target, start)
	else:
		_refresh_sequence()


func _commit_play(card: CardInstance, target: Enemy, start: int) -> void:
	_play_hint.text = "将卡牌拖到这里" if _fight.play_card(card, target, start) else "无法打出这张牌"


func cancel_play() -> void:
	_pending_card = null
	_pending_target = null
	_selected_start = -1
	_selected_count = 0
	_cancel_button.hide()
	_play_hint.text = "将卡牌拖到这里"
	_refresh_sequence()


func _on_hand_changed() -> void:
	if is_instance_valid(_pending_card) and not card_manager.hand.has(_pending_card):
		cancel_play()


func _refresh_sequence() -> void:
	if not is_instance_valid(card_manager):
		return
	var starts: Array[int] = []
	var cost := 0
	if is_instance_valid(_pending_card):
		starts = card_manager.get_play_positions(card_manager.hand.find(_pending_card))
		if starts.is_empty() or (_selected_start >= 0 and _selected_start not in starts):
			cancel_play()
			return
		cost = _pending_card.card.sequence_cost.size()
		_play_hint.text = "%s · 选择序列 %d/%d" % [_pending_card.card.display_name, _selected_count, cost]
	_sequence.display(card_manager.sequence.get_symbols(), starts, cost, _selected_start, _selected_count)
