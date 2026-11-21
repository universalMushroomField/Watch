extends Control
## 通用设置菜单。
## 基础设置负责保存和恢复，具体游戏可以通过 custom_settings_container 追加自己的控件和逻辑。

signal closed
signal setting_changed(key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"

@export var custom_settings_container: Container
@export var master_volume_slider: HSlider
@export var fullscreen_toggle: CheckButton
@export var display_mode_option: OptionButton
@export var close_button: Button

var _settings := ConfigFile.new()
var _is_loading := false

func _ready() -> void:
	if not custom_settings_container:
		custom_settings_container = get_node_or_null("Overlay/Panel/Margin/VBox/CustomSettings")
	if not master_volume_slider:
		master_volume_slider = get_node_or_null("Overlay/Panel/Margin/VBox/GeneralSection/MasterVolume")
	if not fullscreen_toggle:
		fullscreen_toggle = get_node_or_null("Overlay/Panel/Margin/VBox/GeneralSection/Fullscreen")
	if not display_mode_option:
		display_mode_option = get_node_or_null("Overlay/Panel/Margin/VBox/GeneralSection/DisplayMode")
	if not close_button:
		close_button = get_node_or_null("Overlay/Panel/Margin/VBox/Buttons/Close")

	_load_settings()
	_connect_controls()

func _connect_controls() -> void:
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if fullscreen_toggle:
		fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	if display_mode_option:
		display_mode_option.item_selected.connect(_on_display_mode_selected)
	if close_button:
		close_button.pressed.connect(close)

func _load_settings() -> void:
	_is_loading = true
	_settings.load(SETTINGS_PATH)
	if master_volume_slider:
		master_volume_slider.value = float(_settings.get_value("audio", "master_volume", 1.0))
	if fullscreen_toggle:
		fullscreen_toggle.button_pressed = bool(_settings.get_value("display", "fullscreen", false))
	if display_mode_option:
		display_mode_option.select(int(_settings.get_value("display", "mode", 0)))
	_apply_display_settings(false)
	_apply_audio_settings()
	_is_loading = false

func _save_setting(section: String, key: String, value: Variant) -> void:
	_settings.set_value(section, key, value)
	_settings.save(SETTINGS_PATH)
	setting_changed.emit("%s/%s" % [section, key], value)

func _on_master_volume_changed(value: float) -> void:
	if _is_loading:
		return
	_save_setting("audio", "master_volume", value)
	_apply_audio_settings()

func _on_fullscreen_toggled(_pressed: bool) -> void:
	if _is_loading:
		return
	_save_setting("display", "fullscreen", fullscreen_toggle.button_pressed)
	_apply_display_settings()

func _on_display_mode_selected(index: int) -> void:
	if _is_loading:
		return
	_save_setting("display", "mode", index)
	_apply_display_settings()

func _apply_audio_settings() -> void:
	if not master_volume_slider:
		return
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(master_volume_slider.value, 0.0001)))

func _apply_display_settings(resize_window: bool = true) -> void:
	if not fullscreen_toggle or not display_mode_option:
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen_toggle.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not resize_window:
		return
	var sizes := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
	var index := clampi(display_mode_option.selected, 0, sizes.size() - 1)
	if not fullscreen_toggle.button_pressed:
		DisplayServer.window_set_size(sizes[index])

## 供具体游戏添加设置控件。控件应自行连接信号，并可通过 setting_changed 对外同步。
func add_custom_setting(control: Control) -> void:
	if custom_settings_container and control:
		custom_settings_container.add_child(control)

## 供具体游戏在打开菜单时读取已保存的自定义设置。
func get_saved_setting(section: String, key: String, default_value: Variant = null) -> Variant:
	_settings.load(SETTINGS_PATH)
	return _settings.get_value(section, key, default_value)

func close() -> void:
	closed.emit()
	queue_free()
