## 地图视图。
##
## 显示当前幕的六边形蜂巢和崩解度，点击已探索节点的未探索邻居前进；节点内容以占位面板
## 呈现，战斗节点暂时用「视为胜利」跳过，方便先跑通地图流程。既作为 run.tscn 的子场景
## 使用，也可以单独运行调试（此时会自己创建一份 [RunState]）。
extends Control

## 地图生成参数，留空时使用默认配置。
@export var map_config: MapConfig
## 本局使用的角色卡组，会在开局时复制一份。
@export var starting_deck: CardDeck
## 单局状态。留空时自己创建一份，方便单独运行地图场景调试。
@export var run_state: RunState

@onready var _act_label: Label = %ActLabel
@onready var _health_label: Label = %HealthLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _deck_label: Label = %DeckLabel
@onready var _decay_label: Label = %DecayLabel
@onready var _decay_bar: ProgressBar = %DecayBar
@onready var _hex_layer: MapHexLayer = $SubViewportContainer/SubViewport/MapLayer0
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
	if map_config == null:
		map_config = MapConfig.new()

	if run_state == null:
		# 作为单局场景的一部分时，向上找 RunState；单独运行地图场景时自己建一份。
		run_state = _find_run_state()
	if run_state == null:
		run_state = RunState.new()
		run_state.name = "RunState"
		add_child(run_state)
		run_state.map_config = map_config
		run_state.starting_deck = starting_deck
	elif run_state.map_config == null:
		run_state.map_config = map_config
	if run_state.starting_deck == null:
		run_state.starting_deck = starting_deck

	var layout := _hex_layer.make_layout(run_state.map_config)
	run = run_state.create_map(layout)

	run.act_started.connect(_on_act_started)
	run.node_entered.connect(_on_node_entered)
	run.node_travel_rejected.connect(_on_node_travel_rejected)
	_board_input.hex_layer = _hex_layer
	_board_input.viewport_container = $SubViewportContainer
	_board_input.sub_viewport = $SubViewportContainer/SubViewport
	_board_input.node_pressed.connect(_on_node_pressed)
	_hex_layer.show_run(run)
	_board_input.set_run(run)
	_refresh()


## 向上查找所属的单局节点，找不到时返回 null。
func _find_run_state() -> RunState:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is RunState:
			return ancestor as RunState
		ancestor = ancestor.get_parent()
	return null


func _refresh() -> void:
	_act_label.text = "第 %d 幕" % (run.act_index + 1)
	_health_label.text = "生命 %d/%d" % [run.player.health, run.player.max_health]
	_gold_label.text = "金币 %d" % run.player.gold
	_deck_label.text = "卡组 %d 张" % run.player.get_deck_size()
	var percent := roundi(run.get_decay_ratio() * 100.0)
	_decay_label.text = "崩解度 %d%%（%d/%d）" % [percent, run.get_decay_visited_count(), run.get_decay_total_count()]
	_decay_bar.value = run.get_decay_ratio()
	_hex_layer.refresh()


func _on_act_started(_act_index: int, _graph: MapGraph) -> void:
	_hex_layer.show_run(run)
	_board_input.set_run(run)
	_refresh()
	_show_status("第 %d 幕开始，崩解度已重置。" % (run.act_index + 1))


func _on_node_entered(node: MapNode) -> void:
	_refresh()
	_open_panel(node.get_type_label())
	var location := _hex_layer.get_location(node.id)
	if location != null and location.content_scene != null:
		_choices.add_child(location.content_scene.instantiate())
	if node.type == MapNode.Type.BOSS:
		_add_action("进入下一幕", _advance_act)
	else:
		_add_action("返回地图", _close_panel)

func _on_node_travel_rejected(_node_id: int) -> void:
	_show_status("只能前往已探索节点的未探索邻居。")


func _on_node_pressed(node: MapNode) -> void:
	if _panel_open or node.id == run.current_id:
		return
	run.travel_to(node.id)


func _advance_act() -> void:
	run.advance_act()
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
