extends SceneTree

## 卡组配置测试：验证抽牌数与序列上限只有 deck.tres 一个来源，
## 并且 CardManager 把它们真正接到运行时对象上。

const CHARACTER_SCENE := "res://character/templates/character_a.tscn"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var character: Node = load(CHARACTER_SCENE).instantiate()
	var deck := character.get("deck") as CardDeck
	_check(deck != null, "角色绑定了卡组资源")
	if deck == null:
		character.free()
		_finish()
		return

	_check(deck.turn_draw_count == 8, "卡组每回合抽 8 张（实际 %d）" % deck.turn_draw_count)
	_check(deck.sequence_limit == 6, "卡组序列上限是 6（实际 %d）" % deck.sequence_limit)
	_check(deck.sequence_carryover == 2, "卡组回合继承 2 个符号（实际 %d）" % deck.sequence_carryover)

	# 角色节点上不应再有另一份同名数值，否则会变成“改了不生效”的第二个来源。
	for property in character.get_property_list():
		var name: String = property.get("name", "")
		_check(name != "turn_draw_count" and name != "sequence_limit", "角色节点不再导出 %s" % name)

	var manager := CardManager.new()
	manager.get_deck(deck)
	_check(manager.sequence.max_length == 6, "运行时 CardSequence.max_length 是 6（实际 %d）" % manager.sequence.max_length)
	_check(int(manager.get("_turn_draw_count")) == 8, "运行时每回合抽牌数是 8")
	_check(int(manager.get("_sequence_carryover")) == 2, "运行时回合继承长度是 2")

	var drawn := manager.start_turn()
	_check(drawn.size() == 8, "首回合实际抽到 8 张（实际 %d）" % drawn.size())

	# 连续压入超过上限的符号，验证上限真的在裁剪序列。
	for index in range(10):
		manager.sequence.push(CardSequence.Symbol.ATTACK)
	_check(manager.sequence.get_symbols().size() == 6, "序列长度被限制在 6（实际 %d）" % manager.sequence.get_symbols().size())

	manager.free()
	character.free()
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("DECK CONFIG TEST PASSED")
		quit(0)
		return
	print("DECK CONFIG TEST FAILED: %d" % _failures)
	quit(1)