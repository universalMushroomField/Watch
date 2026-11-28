extends CanvasLayer

@onready var panel: Control = $Overlay
@onready var win: Button = %Win

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	win.pressed.connect(_win)
	%Close.pressed.connect(panel.hide)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != KEY_SLASH or not ProjectSettings.get_setting("watch/debug/enabled", false):
		return
	get_viewport().set_input_as_handled()
	panel.visible = not panel.visible
	if panel.visible:
		win.disabled = _battle() == null
		%Close.grab_focus() if win.disabled else win.grab_focus()

func _battle() -> BaseFight:
	var battle := get_tree().get_first_node_in_group("active_battles") as BaseFight
	if battle == null or battle.is_queued_for_deletion() or battle.cur_stage == BattlePhase.Stage.FINISHED:
		return null
	return battle

func _win() -> void:
	panel.hide()
	var battle := _battle()
	if battle != null and ProjectSettings.get_setting("watch/debug/enabled", false):
		battle.debug_win()
