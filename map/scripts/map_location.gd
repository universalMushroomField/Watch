class_name MapLocation
extends Node3D

@export var content_scene: PackedScene

@onready var attachment: Node3D = $AttachmentPoint
@onready var interaction: Node3D = $InteractionPoint
@onready var label: Label3D = $InteractionPoint/Label
@onready var label_color := label.modulate

@onready var _attachment_scale := attachment.scale
@onready var _interaction_scale := interaction.scale


func update_zoom_scale(factor: float) -> void:
	attachment.scale = _attachment_scale * factor
	interaction.scale = _interaction_scale * factor
