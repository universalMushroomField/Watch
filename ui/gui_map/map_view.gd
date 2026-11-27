## 地图视图。
##
## 显示当前幕的六边形蜂巢和崩解度，点击已探索节点的未探索邻居前进；节点内容以占位面板
## 呈现，战斗节点暂时用「视为胜利」跳过，方便先跑通地图流程。既作为 run.tscn 的子场景
## 使用，也可以单独运行调试（此时会自己创建一份 [RunState]）。
extends Control

@export var content_scenes: Dictionary[MapNode.Type, PackedScene] = {
	MapNode.Type.BATTLE: preload("res://ui/gui_map/content/battle.tscn"),
	MapNode.Type.BOSS: preload("res://ui/gui_map/content/boss.tscn"),
	MapNode.Type.ELITE: preload("res://ui/gui_map/content/elite.tscn"),
	MapNode.Type.EVENT: preload("res://ui/gui_map/content/event.tscn"),
	MapNode.Type.REST: preload("res://ui/gui_map/content/rest.tscn"),
	MapNode.Type.HUB: preload("res://ui/gui_map/content/hub.tscn"),
	MapNode.Type.SHOP: preload("res://ui/gui_map/content/shop.tscn"),
	MapNode.Type.START: preload("res://ui/gui_map/content/start.tscn"),
	MapNode.Type.TREASURE: preload("res://ui/gui_map/content/treasure.tscn"),
}

## 单局状态。留空时自己创建一份，方便单独运行地图场景调试。
@export var run_state: RunState

@onready var _act_label: Label = %ActLabel
@onready var _health_label: Label = %HealthLabel
@onready var _currency_icon: TextureRect = %CurrencyIcon
@onready var _gold_label: Label = %GoldLabel
@onready var _deck_label: Label = %DeckLabel
@onready var _decay_label: Label = %DecayLabel
@onready var _decay_bar: ProgressBar = %DecayBar
@onready var _hex_layer: MapHexLayer = %MapLayer0
@onready var _board_input: MapBoardInput = %BoardInput
@onready var _status_label: Label = %StatusLabel
@onready var _overlay: Control = %Overlay
@onready var _panel_title: Label = %PanelTitle
@onready var _choices: VBoxContainer = %Choices

## 当前的地图进度。
var run: MapRun
var _status_tween: Tween
var _panel_open := false


func _ready() -> void:
	if run_state == null:
		run_state = RunState.new()
		run_state.name = "RunState"
		add_child(run_state)

	run_state.prepare()
	_status_label.text = GameText.shared().travel_hint
	var layout := _hex_layer.make_layout(run_state.map_config)
	run = run_state.create_map(layout)

	run_state.act_started.connect(_on_act_started)
	run.node_entered.connect(_on_node_entered)
	run.node_travel_rejected.connect(_on_node_travel_rejected)
	_board_input.node_pressed.connect(_on_node_pressed)
	_hex_layer.show_run(run)
	_board_input.set_run(run)
	_refresh()


func _refresh() -> void:
	var copy := GameText.shared()
	_act_label.text = copy.act_label_format % (run_state.act_index + 1)
	_health_label.text = copy.health_label_format % [
		run_state.player.health, run_state.player.max_health]
	_gold_label.text = copy.currency_amount_format % [copy.currency_name, run_state.player.gold]
	_currency_icon.texture = copy.currency_icon
	_currency_icon.visible = copy.currency_icon != null
	_deck_label.text = copy.deck_label_format % run_state.player.get_deck_size()
	var stage := run.get_extreme_stage()
	_decay_label.text = copy.decay_label_format % [run.extreme_steps, stage, MapRun.STAGE_NAMES[stage]]
	_decay_bar.value = run.get_decay_ratio()
	_hex_layer.refresh()


func _on_act_started(_act_index: int, _graph: MapGraph) -> void:
	_hex_layer.show_run(run)
	_board_input.set_run(run)
	_refresh()
	_show_status(GameText.shared().act_started_format % (run_state.act_index + 1))


func _on_node_entered(node: MapNode) -> void:
	_refresh()
	_open_panel(node.get_type_label())
	var content: PackedScene = content_scenes.get(node.type)
	if content != null:
		_choices.add_child(content.instantiate())
	if node.type == MapNode.Type.BOSS:
		var copy := GameText.shared()
		_add_action(copy.next_act_action, _advance_act)
	else:
		_add_action(GameText.shared().close_panel_action, _close_panel)

func _on_node_travel_rejected(_node_id: int) -> void:
	_show_status(GameText.shared().travel_rejected_message)


func _on_node_pressed(node: MapNode) -> void:
	if _panel_open or node.id == run.current_id:
		return
	run.travel_to(node.id)


func _advance_act() -> void:
	run_state.advance_act()
	_close_panel()


func _open_panel(title: String) -> void:
	_panel_title.text = title
	_clear_choices()
	_overlay.visible = true
	_panel_open = true


func _close_panel() -> void:
	_overlay.visible = false
	_panel_open = false
	_refresh()


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()


func _add_action(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(callback)
	_choices.add_child(button)
	return button


## 在底部状态栏显示提示，1.5 秒后淡出。
func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.modulate.a = 1.0
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(1.5)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)
