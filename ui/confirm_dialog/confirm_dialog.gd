class_name ConfirmDialog
extends Control
## 通用确认弹窗。
##
## 用法：实例化后设置 message / confirm_text / cancel_text，添加到当前场景即可。
## 点击「确定」发出 confirmed，点击「取消」或按 Esc 发出 cancelled，随后自动释放。

signal confirmed
signal cancelled

@export_multiline var message: String = "确定吗？":
	set(value):
		message = value
		if is_node_ready() and _message_label != null:
			_message_label.text = value

@export var confirm_text: String = "确定":
	set(value):
		confirm_text = value
		if is_node_ready() and _confirm_button != null:
			_confirm_button.text = value

@export var cancel_text: String = "取消":
	set(value):
		cancel_text = value
		if is_node_ready() and _cancel_button != null:
			_cancel_button.text = value

@onready var _message_label: Label = %MessageLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	_message_label.text = message
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	_confirm_button.pressed.connect(_on_confirm_button_pressed)
	_cancel_button.pressed.connect(_on_cancel_button_pressed)
	_cancel_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()


## 与按下「取消」等效，供外部代码调用。
func cancel() -> void:
	cancelled.emit()
	queue_free()


func _on_confirm_button_pressed() -> void:
	confirmed.emit()
	queue_free()


func _on_cancel_button_pressed() -> void:
	cancel()