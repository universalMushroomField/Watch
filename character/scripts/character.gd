## 最基本的角色类

extends Node
class_name Character
@export var character_id:String;
@export var character_name:String;
@export var life_count: int = 10:
	set(value):
		life_count = value
		_refresh_health_bar()
@export var sprite:AnimatedSprite2D
signal died(character: Character)

const HEALTH_BAR := preload("res://ui/character/health_bar.tscn")

var _health_bar: ProgressBar
var _initial_health: int
var armor: int = 0:
	set(value):
		armor = value
		_refresh_health_bar()
var _blocked_sources: Array[Character] = []


func _ready() -> void:
	_initial_health = maxi(1, life_count)
	if sprite == null:
		return
	_health_bar = HEALTH_BAR.instantiate() as ProgressBar
	sprite.add_child(_health_bar)
	sprite.frame_changed.connect(_refresh_health_bar)
	_refresh_health_bar()


func _refresh_health_bar() -> void:
	if _health_bar == null:
		return
	var capacity := maxi(_initial_health, life_count)
	_health_bar.max_value = capacity
	_health_bar.value = life_count
	var text := _health_bar.get_node("HealthText") as Label
	text.text = "%d / %d" % [maxi(0, life_count), capacity]
	var armor_text := _health_bar.get_node("ArmorText") as Label
	armor_text.text = "甲 %d" % armor
	var bounds := _sprite_bounds()
	_health_bar.position = Vector2(bounds.get_center().x - _health_bar.size.x * 0.5, bounds.end.y + 8.0)


func has_sprite_at(viewport_position: Vector2) -> bool:
	if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
		return false
	var local := sprite.get_global_transform_with_canvas().affine_inverse() * viewport_position
	return _sprite_bounds().has_point(local)


func _sprite_bounds() -> Rect2:
	var bounds := Rect2(sprite.offset, Vector2.ZERO)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(sprite.animation):
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if texture != null:
			bounds.size = texture.get_size()
	if sprite.centered:
		bounds.position -= bounds.size * 0.5
	return bounds


## 承受来自指定单位的伤害，返回实际损失的生命值。
func take_damage(amount: int, source: Character = null) -> int:
	return apply_resolved_damage(prepare_damage(amount, source))


## 提交伤害时消耗护甲或一次抵消，锁定待结算的伤害。
func prepare_damage(amount: int, source: Character = null) -> int:
	if amount <= 0 or life_count <= 0:
		return 0
	var blocked := _blocked_sources.find(source)
	if blocked >= 0:
		_blocked_sources.remove_at(blocked)
		return 0
	var absorbed := mini(armor, amount)
	armor -= absorbed
	return amount - absorbed


func apply_resolved_damage(amount: int) -> int:
	if amount <= 0 or life_count <= 0:
		return 0
	var lost := mini(life_count, amount)
	life_count -= lost
	if life_count == 0:
		_on_death()
	return lost


## 令指定敌人的下一次伤害无效。
func block_next_damage_from(source: Character) -> void:
	_blocked_sources.append(source)


## 清除上一回合剩余的伤害无效次数。
func clear_damage_blocks() -> void:
	_blocked_sources.clear()


func _on_death() -> void:
	died.emit(self)
