extends Control
## 地图调试界面。
##
## 显示当前幕的放射状地图和崩解度，点击已探索节点的未探索邻居前进；节点内容以占位面板
## 呈现，战斗节点暂时用「视为胜利」跳过，方便先跑通地图流程。

## 地图生成参数，留空时使用默认配置。
@export var map_config: MapConfig
## 事件、商店与占位奖励，留空时使用空内容池。
@export var content_pool: MapContentPool
## 本局使用的角色卡组，会在开局时复制一份。
@export var starting_deck: CardDeck

@onready var _act_label: Label = %ActLabel
@onready var _health_label: Label = %HealthLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _deck_label: Label = %DeckLabel
@onready var _decay_label: Label = %DecayLabel
@onready var _decay_bar: ProgressBar = %DecayBar
@onready var _canvas: MapCanvas = %MapCanvas
@onready var _status_label: Label = %StatusLabel
@onready var _overlay: Control = %Overlay
@onready var _panel_title: Label = %PanelTitle
@onready var _panel_body: Label = %PanelBody
@onready var _choices: VBoxContainer = %Choices

## 当前的地图进度。
var run: MapRun
var _shop_entries: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _status_tween: Tween
var _panel_open := false


func _ready() -> void:
	_rng.randomize()
	if map_config == null:
		map_config = MapConfig.new()
	if content_pool == null:
		content_pool = MapContentPool.new()

	run = MapRun.new(map_config, MapPlayerState.new(70, 50, starting_deck))
	run.act_started.connect(_on_act_started)
	run.node_entered.connect(_on_node_entered)
	run.node_travel_rejected.connect(_on_node_travel_rejected)
	_canvas.node_pressed.connect(_on_canvas_node_pressed)
	_canvas.set_run(run)
	_refresh()


func _refresh() -> void:
	_act_label.text = "第 %d 幕" % (run.act_index + 1)
	_health_label.text = "生命 %d/%d" % [run.player.health, run.player.max_health]
	_gold_label.text = "金币 %d" % run.player.gold
	_deck_label.text = "卡组 %d 张" % run.player.get_deck_size()
	var percent := roundi(run.get_decay_ratio() * 100.0)
	_decay_label.text = "崩解度 %d%%（%d/%d）" % [percent, run.get_visited_count(), run.get_total_node_count()]
	_decay_bar.value = run.get_decay_ratio()
	_canvas.queue_redraw()


func _on_act_started(_act_index: int, _graph: MapGraph) -> void:
	_canvas.set_run(run)
	_refresh()
	_show_status("第 %d 幕开始，崩解度已重置。" % (run.act_index + 1))


func _on_node_entered(node: MapNode) -> void:
	_refresh()
	match node.type:
		MapNode.Type.BATTLE, MapNode.Type.ELITE:
			_open_combat_placeholder(node)
		MapNode.Type.EVENT:
			_open_event()
		MapNode.Type.TREASURE:
			_open_treasure()
		MapNode.Type.SHOP:
			_open_shop()
		MapNode.Type.REST:
			_open_rest()
		MapNode.Type.BOSS:
			_open_boss()
		_:
			_open_panel(node.get_type_label(), "这里什么也没有发生。")
			_add_action("继续", _close_panel)


func _on_node_travel_rejected(_node_id: int) -> void:
	_show_status("只能前往已探索节点的未探索邻居。")


func _on_canvas_node_pressed(node: MapNode) -> void:
	if _panel_open or node.id == run.current_id:
		return
	run.travel_to(node.id)


func _open_combat_placeholder(node: MapNode) -> void:
	var is_elite := node.type == MapNode.Type.ELITE
	var gold_min := content_pool.elite_gold_min if is_elite else content_pool.battle_gold_min
	var gold_max := content_pool.elite_gold_max if is_elite else content_pool.battle_gold_max
	var gold := _rng.randi_range(mini(gold_min, gold_max), maxi(gold_min, gold_max))
	_open_panel(node.get_type_label(), "战斗系统尚未接入。\n本次视为胜利，可获得 %d 金币。" % gold)
	_add_action("视为胜利", func() -> void:
		run.player.add_gold(gold)
		_show_status("获得 %d 金币" % gold)
		_close_panel())


func _open_treasure() -> void:
	var gold := _rng.randi_range(
		mini(content_pool.treasure_gold_min, content_pool.treasure_gold_max),
		maxi(content_pool.treasure_gold_min, content_pool.treasure_gold_max))
	_open_panel("宝箱", "箱子里有 %d 金币。" % gold)
	_add_action("领取", func() -> void:
		run.player.add_gold(gold)
		_show_status("获得 %d 金币" % gold)
		_close_panel())


func _open_rest() -> void:
	var amount := roundi(float(run.player.max_health) * content_pool.rest_heal_ratio)
	_open_panel("休息点", "可以在此休整，恢复 %d 点生命。" % amount)
	_add_action("休息", func() -> void:
		var healed := run.player.heal(amount)
		_show_status("恢复了 %d 点生命" % healed)
		_close_panel())


func _open_event() -> void:
	if content_pool.events.is_empty():
		_open_panel("未知事件", "这里空无一物。")
		_add_action("继续", _close_panel)
		return
	var event: MapEventData = content_pool.events[_rng.randi_range(0, content_pool.events.size() - 1)]
	_show_event(event)


func _show_event(event: MapEventData) -> void:
	_open_panel(event.title, event.body)
	if event.choices.is_empty():
		_add_action("继续", _close_panel)
		return
	for choice in event.choices:
		if choice == null:
			continue
		_add_action(choice.label, func() -> void: _resolve_choice(choice, event))


func _resolve_choice(choice: MapEventChoice, event: MapEventData) -> void:
	choice.apply(run.player)
	var result := choice.result_text if not choice.result_text.is_empty() else "你做出了选择。"
	_open_panel(event.title, result)
	_add_action("继续", _close_panel)


func _open_shop() -> void:
	_shop_entries.clear()
	var stock := content_pool.shop_stock
	if stock != null:
		for entry in stock.entries:
			if entry != null and entry.card != null and entry.stock > 0:
				_shop_entries.append({"entry": entry, "stock": entry.stock})
	_show_shop()


func _show_shop() -> void:
	var lines: Array[String] = ["你的金币：%d" % run.player.gold, ""]
	if _shop_entries.is_empty():
		lines.append("货架已经空了。")
	else:
		for item in _shop_entries:
			var entry: ShopEntry = item["entry"]
			lines.append("%s — %d 金币（剩 %d）" % [entry.card.display_name, entry.price, item["stock"]])
	_open_panel("商店", "\n".join(lines))

	for item in _shop_entries:
		var entry: ShopEntry = item["entry"]
		if int(item["stock"]) <= 0:
			continue
		_add_action("购买 %s（%d 金币）" % [entry.card.display_name, entry.price],
			func() -> void: _buy_card(item))

	var stock := content_pool.shop_stock
	if stock != null:
		_add_action("治疗 %d 生命（%d 金币）" % [stock.heal_amount, stock.heal_price],
			func() -> void: _buy_heal(stock))
	_add_action("离开", _close_panel)


func _buy_card(item: Dictionary) -> void:
	var entry: ShopEntry = item["entry"]
	if not run.player.spend_gold(entry.price):
		_show_status("金币不足")
		return
	run.player.add_card(entry.card)
	item["stock"] = int(item["stock"]) - 1
	_show_status("购买了「%s」" % entry.card.display_name)
	_show_shop()
	_refresh()


func _buy_heal(stock: ShopStockData) -> void:
	if not run.player.spend_gold(stock.heal_price):
		_show_status("金币不足")
		return
	var healed := run.player.heal(stock.heal_amount)
	_show_status("恢复了 %d 点生命" % healed)
	_show_shop()
	_refresh()


func _open_boss() -> void:
	_open_panel("关底 Boss", "本幕探索结束。\n崩解度 %d%%，已探索 %d/%d 个节点。" % [
		roundi(run.get_decay_ratio() * 100.0),
		run.get_visited_count(),
		run.get_total_node_count()])
	_add_action("进入下一幕", _advance_act)


func _advance_act() -> void:
	run.advance_act()
	_close_panel()


func _open_panel(title: String, body: String) -> void:
	_panel_title.text = title
	_panel_body.text = body
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
