extends Control

const CARD_VIEW := preload("res://cards/templates/sprite_tscn/default_card_sprite.tscn")
const RUN := preload("res://run/templates/run.tscn")
@export var characters: Array[PackedScene] = [preload("res://character/templates/character_a.tscn")]

var selected: PackedScene

func _ready() -> void:
	var group := ButtonGroup.new()
	for scene in characters:
		var character := scene.instantiate() as CharacterSelectable
		var button := Button.new()
		button.text = character.character_name
		button.toggle_mode = true
		button.button_group = group
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		if character.sprite != null:
			var sprite := character.sprite
			button.icon = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		button.pressed.connect(_select.bind(scene, character.character_name, character.deck))
		%Roster.add_child(button)
		character.free()
	%Confirm.pressed.connect(_confirm)
	%Back.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/start_menu/start_menu.tscn"))
	if %Roster.get_child_count() > 0:
		%Roster.get_child(0).grab_focus()


func _select(scene: PackedScene, title: String, deck: CardDeck) -> void:
	selected = scene
	for child in %Cards.get_children():
		%Cards.remove_child(child)
		child.queue_free()
	%Confirm.disabled = deck == null
	var count := 0
	if deck != null:
		for card in deck.cards:
			var view := CARD_VIEW.instantiate() as CardView
			view.show_card(card)
			view.set_process(false)
			%Cards.add_child(view)
			count += 1
	%DeckTitle.text = "%s 的初始卡组（%d 张）" % [title, count]
	%Scroll.scroll_vertical = 0


func _confirm() -> void:
	if selected == null or %Confirm.disabled:
		return
	var run := RUN.instantiate() as RunState
	run.player_character = selected.instantiate() as CharacterSelectable
	if run.player_character.sprite != null:
		run.player_character.sprite.hide()
	run.add_child(run.player_character)
	get_tree().change_scene_to_node(run)
