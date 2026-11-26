extends SceneTree

## 序列符号命名约定测试。
##
## 约定：代码里一律用 `CardSequence.Symbol.RED` / `BLUE` / `YI`，玩家看到的字只来自
## 文案资源 `ui/text/game_text.tres`。枚举下标被 `.tres` 直接序列化成整数
## （例如 `sequence_cost = Array[int]([0, 1])`、`kind = 0`），所以下标同样是约定的一部分。

const CARD_DIR := "res://cards/templates/character_a/card_tres/"

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(int(CardSequence.Symbol.RED) == 0, "Symbol.RED 的下标是 0（实际 %d）" % CardSequence.Symbol.RED)
	_check(int(CardSequence.Symbol.BLUE) == 1, "Symbol.BLUE 的下标是 1（实际 %d）" % CardSequence.Symbol.BLUE)
	_check(int(CardSequence.Symbol.YI) == 2, "Symbol.YI 的下标是 2（实际 %d）" % CardSequence.Symbol.YI)

	_check(int(CardData.Kind.RED) == int(CardSequence.Symbol.RED), "Kind.RED 与 Symbol.RED 下标一致")
	_check(int(CardData.Kind.BLUE) == int(CardSequence.Symbol.BLUE), "Kind.BLUE 与 Symbol.BLUE 下标一致")

	var copy := GameText.shared()
	_check(copy != null, "文案资源可加载")
	if copy != null:
		var names := {
			CardSequence.Symbol.RED: copy.symbol_red_name,
			CardSequence.Symbol.BLUE: copy.symbol_blue_name,
			CardSequence.Symbol.YI: copy.symbol_yi_name,
		}
		var seen := {}
		for symbol in names:
			var text: String = names[symbol]
			_check(not text.is_empty(), "文案资源配置了符号 %d 的显示名" % symbol)
			_check(not seen.has(text), "符号 %d 的显示名与其它符号重复：%s" % [symbol, text])
			seen[text] = true
			_check(copy.symbol_name(symbol) == text, "symbol_name(%d) 返回配置的名字" % symbol)
		_check(not copy.sequence_empty_text.is_empty(), "文案资源配置了空序列提示")

	# 基础红蓝牌的资源必须与枚举下标对得上，否则牌推出的是错的符号。
	var red_card := load(CARD_DIR + "attack.tres") as CardData
	_check(red_card != null and red_card.kind == CardData.Kind.RED, "attack.tres 是红牌")
	var blue_card := load(CARD_DIR + "defense.tres") as CardData
	_check(blue_card != null and blue_card.kind == CardData.Kind.BLUE, "defense.tres 是蓝牌")

	_check_selector_text(copy)

	_finish()


## 序列条上的文字必须从文案资源取，不能在 UI 脚本里再硬编码一份。
func _check_selector_text(copy: GameText) -> void:
	var selector := SequenceSelector.new()
	root.add_child(selector)
	var symbols: Array[CardSequence.Symbol] = [
		CardSequence.Symbol.RED, CardSequence.Symbol.BLUE, CardSequence.Symbol.YI]
	selector.display(symbols, [0], 1, -1, 0)
	var labels: Array[String] = []
	for child in selector.get_children():
		if child is Button:
			labels.append((child as Button).text)
	_check(labels == [copy.symbol_red_name, copy.symbol_blue_name, copy.symbol_yi_name],
		"序列条按钮显示文案资源里的名字（实际 %s）" % [labels])

	selector.display([] as Array[CardSequence.Symbol], [], 0, -1, 0)
	var empty_text := ""
	for child in selector.get_children():
		if child is Label:
			empty_text = (child as Label).text
	_check(empty_text == copy.sequence_empty_text, "空序列提示来自文案资源（实际 %s）" % empty_text)

	selector.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: %s" % message)


func _finish() -> void:
	if _failures == 0:
		print("SYMBOL TEXT TEST PASSED")
		quit(0)
		return
	print("SYMBOL TEXT TEST FAILED: %d" % _failures)
	quit(1)