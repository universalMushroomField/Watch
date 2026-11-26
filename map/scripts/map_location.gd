class_name MapLocation
extends Node3D

## 本地点类型在色板里的下标，见 [ArtPalette]。
@export var palette_index: int = 0

@onready var attachment: Node3D = $AttachmentPoint
@onready var interaction: Node3D = $InteractionPoint
@onready var label: Label3D = $InteractionPoint/Label
## 本类型的色板色；`MapHexLayer.refresh()` 用它派生可达与不可达状态。
var label_color := Color.WHITE

@onready var _attachment_scale: Vector3 = attachment.scale
@onready var _interaction_scale: Vector3 = interaction.scale


func _ready() -> void:
	label_color = ArtPalette.color(palette_index)
	label.modulate = label_color
	_paint_marker(attachment, label_color)
	_paint_marker(interaction, label_color)


func update_zoom_scale(factor: float) -> void:
	attachment.scale = _attachment_scale * factor
	interaction.scale = _interaction_scale * factor


## 小球是不投影的纯色材质，颜色统一取自色板，覆盖模板里的编辑器预览色。
func _paint_marker(point: Node3D, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	for child in point.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material