## 地图蜂巢顶点上的一个地点。
##
## 视觉状态只有四种（见 [enum State]）；球体、标签和标记环（[MapHighlight]）始终同色，
## 这样「可前往 / 已访问 / 还没走到」不会出现球一个色、字另一个色。
class_name MapLocation
extends Node3D

## 节点在刷新时的呈现状态。
enum State {
	## 没有从任何已探索节点连过来，先淡出成背景。
	UNREACHED,
	## 从某个已探索节点一步可达，本类型色 + 环形标记。
	REACHABLE,
	## 已经走过，本类型色让位给统一的「走过了」色。
	VISITED,
	## 玩家此刻所在的位置，色板里唯一的高饱和红，外加旋转虚线环。
	CURRENT,
}

## 本地点类型在色板里的下标，见 [ArtPalette]。
@export var palette_index: int = 0

@onready var attachment: Node3D = $AttachmentPoint
@onready var interaction: Node3D = $InteractionPoint
@onready var label: Label3D = $InteractionPoint/Label
## 标记环，由 [MapHexLayer] 生成节点时挂到 [member interaction] 上。
var highlight: MapHighlight
## 当前状态。
var state: State = State.UNREACHED

## 玩家所在节点标签的放大倍数。
const CURRENT_LABEL_SCALE := 1.25

var _type_color := Color.WHITE
var _label_height := 0.0
var _attachment_material := StandardMaterial3D.new()
var _interaction_material := StandardMaterial3D.new()

@onready var _attachment_scale: Vector3 = attachment.scale
@onready var _interaction_scale: Vector3 = interaction.scale


func _ready() -> void:
	_type_color = ArtPalette.color(palette_index)
	_label_height = label.position.y
	_paint_marker(attachment, _attachment_material)
	_paint_marker(interaction, _interaction_material)
	apply_state(State.UNREACHED)


## 本地点类型在色板里的颜色。
func get_type_color() -> Color:
	return _type_color


## 某个状态下的球体与标记圆底色。
func get_state_color(next_state: State) -> Color:
	match next_state:
		State.CURRENT:
			return ArtPalette.color(ArtPalette.NODE_CURRENT)
		State.VISITED:
			return ArtPalette.color(ArtPalette.NODE_VISITED)
		State.REACHABLE:
			return _type_color
		_:
			return ArtPalette.fade(palette_index, ArtPalette.NODE_UNREACHED_FADE)


## 标签在某个状态下的颜色。玩家所在节点压在自己的实心圆底上，换成近白色才读得清。
func get_label_color(next_state: State, hovered: bool = false) -> Color:
	if next_state == State.CURRENT:
		return ArtPalette.color(ArtPalette.NODE_CURRENT_LABEL)
	if hovered:
		return ArtPalette.color(ArtPalette.NODE_HOVER)
	return get_state_color(next_state)


## 按状态刷新球体、标签与标记环。[param hovered] 为真时标签和环换成悬停色。
func apply_state(next_state: State, hovered: bool = false) -> void:
	state = next_state
	_attachment_material.albedo_color = get_state_color(next_state)
	_interaction_material.albedo_color = get_state_color(next_state)
	label.modulate = get_label_color(next_state, hovered)
	label.scale = Vector3.ONE * (CURRENT_LABEL_SCALE if next_state == State.CURRENT else 1.0)
	set_label_offset(0.0)
	_apply_highlight(next_state, hovered)


func _apply_highlight(next_state: State, hovered: bool) -> void:
	if highlight == null:
		return
	if next_state == State.CURRENT:
		# 红底上的环用标签的近白色，否则红环套红字会糊成一片。
		highlight.apply(
			MapHighlight.Kind.CURRENT,
			ArtPalette.color(ArtPalette.NODE_CURRENT),
			ArtPalette.color(ArtPalette.NODE_CURRENT_LABEL)
		)
		return
	if next_state == State.REACHABLE:
		if hovered:
			highlight.apply(MapHighlight.Kind.HOVER, ArtPalette.color(ArtPalette.NODE_HOVER))
		else:
			highlight.apply(MapHighlight.Kind.REACHABLE, ArtPalette.color(ArtPalette.NODE_REACHABLE))
		return
	if next_state == State.VISITED and hovered:
		highlight.apply(MapHighlight.Kind.HOVER, ArtPalette.color(ArtPalette.NODE_HOVER))
		return
	highlight.clear()


## 标签相对模板高度的偏移，用来让玩家所在节点的标记与标签一起上下浮动。
func set_label_offset(offset: float) -> void:
	label.position.y = _label_height + offset
	if highlight != null:
		highlight.position.y = _label_height + offset


func update_zoom_scale(factor: float) -> void:
	attachment.scale = _attachment_scale * factor
	interaction.scale = _interaction_scale * factor


## 小球是不投影的纯色材质，颜色统一取自色板，覆盖模板里的编辑器预览色。
## 材质常驻，状态变化时只改 albedo，避免每次刷新都新建材质。
func _paint_marker(point: Node3D, material: StandardMaterial3D) -> void:
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _type_color
	for child in point.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = material
