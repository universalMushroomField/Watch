extends Control
## 开始菜单。
##
## 「开始游戏」「存档」跳转的场景在检查器里配置；未配置时只在底部状态栏提示，不会报错。
## 「设置」打开 ui/setting_menu，覆盖在当前场景之上；「退出游戏」弹出通用确认弹窗。

## 「开始游戏」切换到的场景。
@export var game_scene: PackedScene
## 「存档」切换到的场景。
@export var save_scene: PackedScene

const SETTINGS_MENU_SCENE := preload("res://ui/setting_menu/setting_menu.tscn")
const CONFIRM_DIALOG_SCENE := preload("res://ui/confirm_dialog/confirm_dialog.tscn")

@onready var _start_button: Button = %StartButton
@onready var _save_button: Button = %SaveButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel

var _status_tween: Tween


func _ready() -> void:
	_start_button.pressed.connect(_on_start_button_pressed)
	_save_button.pressed.connect(_on_save_button_pressed)
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_quit_button.pressed.connect(_on_quit_button_pressed)
	_start_button.grab_focus()


func _on_start_button_pressed() -> void:
	_change_scene(game_scene, "开始游戏")


func _on_save_button_pressed() -> void:
	_change_scene(save_scene, "存档")


func _on_settings_button_pressed() -> void:
	if get_node_or_null("SettingMenu") != null:
		return
	add_child(SETTINGS_MENU_SCENE.instantiate())


func _on_quit_button_pressed() -> void:
	if get_node_or_null("ConfirmDialog") != null:
		return
	var dialog := CONFIRM_DIALOG_SCENE.instantiate() as ConfirmDialog
	dialog.message = "确定要退出游戏吗？"
	dialog.confirm_text = "退出"
	dialog.confirmed.connect(_on_quit_confirmed)
	add_child(dialog)


func _on_quit_confirmed() -> void:
	get_tree().quit()


## 切换主场景；场景未配置时提示，避免空引用报错。
func _change_scene(scene: PackedScene, action_name: String) -> void:
	if scene == null:
		_show_status("「%s」场景尚未配置" % action_name)
		return
	get_tree().change_scene_to_packed(scene)


## 在底部状态栏显示提示，1.5 秒后淡出。
func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.modulate.a = 1.0
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(1.5)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)
