## 节点标记：一块始终朝向相机的贴片，由 [code]node_highlight.gdshader[/code] 画环。
##
## 三种形态：可前往的细环、悬停的粗环、玩家所在节点的实心圆底 + 旋转虚线环。形态参数集中在
## [constant KIND_STYLE]，颜色由 [MapLocation] 按节点状态传入；呼吸脉冲与虚线旋转在着色器里用 TIME 算。
class_name MapHighlight
extends MeshInstance3D

## 标记形态。
enum Kind {
	## 还能前往的节点：细实线环，轻微呼吸。
	REACHABLE,
	## 鼠标指向的节点：更粗、更亮的环。
	HOVER,
	## 玩家所在节点：实心圆底 + 旋转虚线圈，标签换成白色压在上面。
	CURRENT,
}

## 每种形态的环参数，键名与着色器的 uniform 一致。半径与线宽的单位是贴片 UV，
## 贴片边长 2.4（世界单位），所以 1 UV = 2.4 世界单位：半径必须小于 0.5，否则环会被贴片边缘切掉。
const KIND_STYLE := {
	Kind.REACHABLE: {
		"ring_radius": 0.354,
		"ring_width": 0.0375,
		"inner_ring_radius": 0.0,
		"inner_ring_width": 0.0,
		"disc_radius": 0.0,
		"disc_feather": 0.02,
		"dash_count": 0.0,
		"dash_speed": 0.0,
		"pulse_speed": 2.2,
		"pulse_amount": 0.08,
		"pulse_alpha": 0.35,
	},
	Kind.HOVER: {
		"ring_radius": 0.383,
		"ring_width": 0.064,
		"inner_ring_radius": 0.0,
		"inner_ring_width": 0.0,
		"disc_radius": 0.0,
		"disc_feather": 0.02,
		"dash_count": 0.0,
		"dash_speed": 0.0,
		"pulse_speed": 3.4,
		"pulse_amount": 0.05,
		"pulse_alpha": 0.3,
	},
	Kind.CURRENT: {
		"ring_radius": 0.508,
		"ring_width": 0.042,
		"inner_ring_radius": 0.0,
		"inner_ring_width": 0.0,
		"disc_radius": 0.4375,
		"disc_feather": 0.02,
		"dash_count": 8.0,
		"dash_speed": 0.16,
		"pulse_speed": 3.0,
		"pulse_amount": 0.03,
		"pulse_alpha": 0.25,
	},
}

## 当前形态。
var kind: Kind = Kind.REACHABLE


func _ready() -> void:
	visible = false


## 显示标记。[param next_kind] 决定形状，[param color] 是圆底与环的填充色，
## [param stroke_color] 只换环的颜色（玩家节点用近白色的环压在红底上）；留空表示与 [param color] 同色。
func apply(next_kind: Kind, color: Color, stroke_color: Color = Color.TRANSPARENT) -> void:
	var material := material_override as ShaderMaterial
	if material == null:
		return
	kind = next_kind
	var style: Dictionary = KIND_STYLE[next_kind]
	for uniform in style:
		material.set_shader_parameter(uniform, style[uniform])
	material.set_shader_parameter("fill_color", color if stroke_color.a <= 0.0 else stroke_color)
	material.set_shader_parameter("disc_color", color)
	visible = true


## 隐藏标记。
func clear() -> void:
	visible = false
