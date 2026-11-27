extends Node

const TEXT_SHADER := preload("res://public/shaders/ui/pixel_text.gdshader")
var text_material := ShaderMaterial.new()

func _ready() -> void:
	text_material.shader = TEXT_SHADER
	get_tree().node_added.connect(_apply_text_material)

func _apply_text_material(node: Node) -> void:
	if not (node is Label or node is RichTextLabel or node is Button):
		return
	if node.material == null and not node.use_parent_material:
		node.material = text_material
