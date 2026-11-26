@tool
## 地图底模默认使用源网格，像素尺度由屏幕后处理控制。
class_name MapTerrainModel
extends MeshInstance3D

signal terrain_rebuilt

## 提供地表高度及底面位置的原始高度场网格。
@export var source_mesh: Mesh:
	set(value):
		if source_mesh != null and source_mesh.changed.is_connected(_queue_rebuild):
			source_mesh.changed.disconnect(_queue_rebuild)
		source_mesh = value
		if source_mesh != null:
			source_mesh.changed.connect(_queue_rebuild)
		_queue_rebuild()

@export_group("Voxel Erosion")
## 可选的实体侵蚀模式，用于需要真实阶梯断面和碎岩的场景。
@export var voxelize_terrain := false:
	set(value):
		voxelize_terrain = value
		_queue_rebuild()
## 体素在模型空间中的目标边长。
@export_range(0.2, 4.0, 0.01, "or_greater", "suffix:m") var voxel_size := 0.64:
	set(value):
		voxel_size = maxf(value, 0.2)
		_queue_rebuild()
## 总侵蚀强度。设为零可生成实心的阶梯底模。
@export_range(0.0, 1.0, 0.01) var erosion_strength := 0.86:
	set(value):
		erosion_strength = clampf(value, 0.0, 1.0)
		_queue_rebuild()
## 各列从地表往下保留为完整岩层的厚度比例。
@export_range(0.0, 1.0, 0.01) var intact_depth := 0.16:
	set(value):
		intact_depth = clampf(value, 0.0, 1.0)
		_queue_rebuild()
## 控制相邻空洞和残岩的尺寸。较大的值产生较大的连续断面。
@export_range(0.25, 12.0, 0.05, "or_greater", "suffix:m") var cluster_size := 2.4:
	set(value):
		cluster_size = maxf(value, 0.25)
		_queue_rebuild()
## 只用于编辑器预览。
@export var preview_seed := 1:
	set(value):
		preview_seed = value
		if Engine.is_editor_hint():
			_queue_rebuild()

var _rebuild_queued := false


func _ready() -> void:
	_rebuild()


func _validate_property(property: Dictionary) -> void:
	# 场景只保存源网格和生成参数，避免把编辑器预览一并写入场景。
	if property.name == &"mesh":
		property.usage = PROPERTY_USAGE_NONE


func _queue_rebuild() -> void:
	if is_node_ready() and not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var generated: ArrayMesh
	var terrain_seed := preview_seed
	if voxelize_terrain and source_mesh != null:
		var sampler := MapSurfaceSampler.new()
		sampler.build_mesh(source_mesh)
		if not Engine.is_editor_hint():
			var generator := get_node_or_null("/root/SeedGenerator")
			if generator != null:
				terrain_seed = generator.derive_seed(generator.run_seed, &"terrain_voxels")
		generated = MapVoxelTerrain.build(sampler, voxel_size, erosion_strength, terrain_seed,
				intact_depth, cluster_size)
	mesh = generated if generated != null else source_mesh
	# 旧场景曾把白模的所有渲染层清空，只显示粒子雾。
	if mesh != null and layers == 0:
		set_layer_mask_value(1, true)
	var fog := get_node_or_null("ParticleFog")
	if fog != null:
		fog.visible = generated != null
		if fog.visible:
			fog.rebuild(generated, terrain_seed)
		else:
			fog.multimesh = null
	terrain_rebuilt.emit()
