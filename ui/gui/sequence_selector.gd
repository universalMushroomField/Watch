class_name SequenceSelector
extends HBoxContainer

signal position_selected(index: int)

const SYMBOL_TEXT := ["攻", "守", "易"]
const AVAILABLE_COLOR := Color(0.95, 0.73, 0.32)
const SELECTED_COLOR := Color(0.38, 0.84, 0.77)


func display(symbols: Array[CardSequence.Symbol], starts: Array[int], cost: int, start: int, selected: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if symbols.is_empty():
		var empty := Label.new()
		empty.text = "序列为空"
		add_child(empty)
		return

	var outlined := {}
	for candidate in starts:
		for index in range(candidate, candidate + cost):
			outlined[index] = true

	for index in range(symbols.size()):
		var button := Button.new()
		button.text = SYMBOL_TEXT[symbols[index]]
		button.custom_minimum_size = Vector2(38, 38)
		button.disabled = not (index in starts if start < 0 else index == start + selected)
		if start >= 0 and index >= start and index < start + selected:
			_outline(button, SELECTED_COLOR)
		elif (start < 0 and outlined.has(index)) or (start >= 0 and index == start + selected):
			_outline(button, AVAILABLE_COLOR)
		button.pressed.connect(position_selected.emit.bind(index))
		add_child(button)


func _outline(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.18, 0.24)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	for name in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(name, style)
	button.add_theme_color_override("font_disabled_color", color)
