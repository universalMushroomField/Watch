extends Button

const FACE := preload("res://cards/templates/sprite_tscn/default_card_sprite.tscn")
@onready var preview: SubViewport = $Preview
signal taken
var take_progress := 0.0:
	set(value):
		take_progress = value
		position.y = -44.0 * value
		modulate.a = 1.0 - value
var collect: Callable

func configure(category: String, title: String, scene: PackedScene, grant: Callable, card: CardData = null) -> void:
	$Category.text = category
	$Title.text = title
	collect = grant
	$Image.texture = preview.get_texture()
	if card != null:
		var face := FACE.instantiate() as CardView
		preview.add_child(face)
		face.show_card(card)
		face.position = Vector2(24, 8)
		face.scale = Vector2(1.5, 1.5)
		face.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		var model := scene.instantiate() as Node3D
		preview.add_child(model)
		var camera := Camera3D.new()
		preview.add_child(camera)
		camera.position = Vector3(0, 1, 5)
		camera.look_at(Vector3(0, 0.8, 0))
		var light := DirectionalLight3D.new()
		preview.add_child(light)
		light.rotation_degrees = Vector3(-38,-30,0)
		light.light_energy = 1.7
	pressed.connect(_claim)

func _claim() -> void:
	if disabled:
		return
	disabled = true
	collect.call()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Motion.play("take")
	await $Motion.animation_finished
	hide()
	taken.emit()
	queue_free()
