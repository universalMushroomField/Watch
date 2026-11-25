@tool
class_name CardView
extends Control

const UP := &"card_animation/card_up_move"
const DOWN := &"card_animation/card_down_move"

@onready var artwork: Control = $Artwork
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _hovered := false
var hand_card: CardInstance:
	set(value):
		hand_card = value
		var face := get_node_or_null("Artwork") as Control
		if face != null:
			face.mouse_filter = Control.MOUSE_FILTER_PASS if value != null else Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)


func show_card(card: CardData) -> void:
	if card == null:
		$Artwork/CardName.text = ""
		$Artwork/Description.text = ""
		tooltip_text = ""
		return
	$Artwork/CardName.text = card.display_name
	$Artwork/Description.text = card.description
	tooltip_text = card.display_name + "\n" + card.description
	mouse_filter = Control.MOUSE_FILTER_PASS


func _process(_delta: float) -> void:
	var cursor := get_global_mouse_position()
	var inside := is_visible_in_tree() and (
		artwork.get_global_rect().has_point(cursor)
		or (_hovered and get_global_rect().has_point(cursor))
	)
	if inside == _hovered:
		return
	_hovered = inside
	animation_player.play(UP if _hovered else DOWN)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_instance_valid(hand_card):
		return null
	var preview := duplicate() as CardView
	preview.hand_card = null
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_process(false)
	preview.get_node("Artwork").position = Vector2.ZERO
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview)
	preview.position = -size * 0.5
	set_drag_preview(holder)
	return hand_card
