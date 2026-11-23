@tool
## 为地图生成带台阶的地形底模。
extends MeshInstance3D
class_name MeshGenerator

const DEFAULT_NOISE := preload("res://components/terrain_noise.tres")

@export_tool_button("重建地形") var rebuild_terrain: Callable:
	get:
		return Callable(self, &"regenerate")
@export_tool_button("保存当前网格") var save_terrain: Callable:
	get:
		return Callable(self, &"_choose_mesh_save_path")

@export_group("Grid")

## 地形沿 X、Z 轴的格数。
@export_range(1, 256, 1) var columns: int = 32:
	set(value):
		columns = clampi(value, 1, 256)
		_queue_regeneration()

@export_range(1, 256, 1) var rows: int = 32:
	set(value):
		rows = clampi(value, 1, 256)
		_queue_regeneration()

## 每格水平边长。地图宽度为列数乘以边长。
@export_range(0.05, 16.0, 0.05, "or_greater", "suffix:m") var block_size: float = 0.4:
	set(value):
		block_size = maxf(0.05, value)
		_queue_regeneration()

@export_group("Elevation")

## 生成后地表的平均高度。
@export_range(-32.0, 32.0, 0.05, "or_less", "or_greater", "suffix:m") var base_height: float = 0.0:
	set(value):
		base_height = value
		_queue_regeneration()

## 噪声映射的高度范围，地表随后平移到基准高度。
@export_range(0.0, 64.0, 0.05, "or_greater", "suffix:m") var max_high: float = 2.5:
	set(value):
		max_high = maxf(0.0, value)
		_queue_regeneration()

@export_group("Terraces")

@export var blockify: bool = true:
	set(value):
		blockify = value
		_queue_regeneration()

## 方块模式的垂直台阶高度。
@export_range(0.05, 16.0, 0.05, "or_greater", "suffix:m") var step_height: float = 0.25:
	set(value):
		step_height = maxf(0.05, value)
		_queue_regeneration()

## 底面与最低地表之间的距离。
@export_range(0.05, 16.0, 0.05, "or_greater", "suffix:m") var foundation_depth: float = 0.5:
	set(value):
		foundation_depth = maxf(0.05, value)
		_queue_regeneration()

@export_group("Noise")

## frequency 控制按地形单位采样的起伏尺度。运行时使用本局派生种子。
@export var terrain_noise: FastNoiseLite = DEFAULT_NOISE:
	set(value):
		if terrain_noise != null and terrain_noise.changed.is_connected(_queue_regeneration):
			terrain_noise.changed.disconnect(_queue_regeneration)
		terrain_noise = value
		_watch_noise()
		_queue_regeneration()


var _regeneration_queued := false
var _seed_generator: Node


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_queue_regeneration()


func _ready() -> void:
	_watch_noise()
	if Engine.is_editor_hint():
		_queue_regeneration()
	else:
		set_process(false)
		_seed_generator = get_node_or_null("/root/SeedGenerator")
		if _seed_generator != null:
			_seed_generator.connect(&"run_seed_changed", _queue_regeneration)
		regenerate()


func _process(_delta: float) -> void:
	# 编辑器重新加载工具脚本或清空 Mesh 时，重新填充预览网格。
	if Engine.is_editor_hint() and mesh == null:
		_queue_regeneration()


func _watch_noise() -> void:
	if terrain_noise != null and not terrain_noise.changed.is_connected(_queue_regeneration):
		terrain_noise.changed.connect(_queue_regeneration)


func _queue_regeneration() -> void:
	if not is_inside_tree() or _regeneration_queued:
		return
	_regeneration_queued = true
	_regenerate_queued.call_deferred()


func _regenerate_queued() -> void:
	if _regeneration_queued:
		_regeneration_queued = false
		if is_inside_tree():
			regenerate()


func regenerate() -> void:
	_regeneration_queued = false
	var settings := terrain_noise if terrain_noise != null else DEFAULT_NOISE
	var noise := settings.duplicate() as FastNoiseLite
	if is_instance_valid(_seed_generator):
		noise.seed = _seed_generator.derive_seed(_seed_generator.run_seed, &"terrain")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if blockify:
		surface.set_smooth_group(-1)
		_build_blocks(surface, noise)
	else:
		_build_smooth_surface(surface, noise)
	surface.generate_normals()
	mesh = surface.commit()


func _choose_mesh_save_path() -> void:
	if not Engine.is_editor_hint():
		return
	if mesh == null:
		push_warning("当前没有可保存的地形网格。")
		return
	var dialog := FileDialog.new()
	dialog.title = "保存当前网格"
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.res ; Mesh 资源"])
	dialog.current_file = "terrain_mesh.res"
	dialog.file_selected.connect(_save_mesh.bind(mesh, dialog))
	dialog.canceled.connect(dialog.queue_free)
	var editor := Engine.get_singleton("EditorInterface")
	editor.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.65)


func _save_mesh(path: String, snapshot: Mesh, dialog: FileDialog) -> void:
	if path.get_extension().to_lower() != "res":
		path += ".res"
	var result := ResourceSaver.save(snapshot, path)
	if result != OK:
		push_error("保存网格失败：%s（%s）" % [path, error_string(result)])
	dialog.queue_free()


func _build_blocks(surface: SurfaceTool, noise: FastNoiseLite) -> void:
	var heights := PackedFloat64Array()
	heights.resize(columns * rows)
	var total := 0.0
	for z in range(rows):
		for x in range(columns):
			var height := floorf(_sample_height(noise, x + 0.5, z + 0.5) / step_height) * step_height
			heights[z * columns + x] = height
			total += height

	var shift := base_height - total / heights.size()
	var bottom := heights[0] + shift - foundation_depth
	for height in heights:
		bottom = minf(bottom, height + shift - foundation_depth)
	for z in range(rows):
		for x in range(columns):
			var height := heights[z * columns + x] + shift
			var a := _point(x, z, height)
			var b := _point(x + 1, z, height)
			var c := _point(x + 1, z + 1, height)
			var d := _point(x, z + 1, height)
			_quad(surface, a, b, c, d)
			_block_wall(surface, a, b, heights, x, z - 1, shift, bottom)
			_block_wall(surface, b, c, heights, x + 1, z, shift, bottom)
			_block_wall(surface, c, d, heights, x, z + 1, shift, bottom)
			_block_wall(surface, d, a, heights, x - 1, z, shift, bottom)
	_bottom(surface, bottom)


func _block_wall(surface: SurfaceTool, a: Vector3, b: Vector3,
		heights: PackedFloat64Array, x: int, z: int, shift: float, bottom: float) -> void:
	if x >= 0 and x < columns and z >= 0 and z < rows:
		var neighbor := heights[z * columns + x] + shift
		if neighbor < a.y and not is_equal_approx(neighbor, a.y):
			_wall(surface, a, b, neighbor)
	else:
		_wall(surface, a, b, bottom)


func _build_smooth_surface(surface: SurfaceTool, noise: FastNoiseLite) -> void:
	var stride := columns + 1
	var heights := PackedFloat64Array()
	heights.resize(stride * (rows + 1))
	for z in range(rows + 1):
		for x in range(stride):
			heights[z * stride + x] = _sample_height(noise, x, z)

	# 两个等投影面积的三角形共用对角线，因此其端点各计两次。
	var total := 0.0
	for z in range(rows):
		for x in range(columns):
			var i := z * stride + x
			total += 2.0 * (heights[i] + heights[i + stride + 1]) + heights[i + 1] + heights[i + stride]

	var shift := base_height - total / (6.0 * columns * rows)
	var bottom := heights[0] + shift - foundation_depth
	for height in heights:
		bottom = minf(bottom, height + shift - foundation_depth)
	for z in range(rows):
		for x in range(columns):
			var i := z * stride + x
			_quad(surface, _point(x, z, heights[i] + shift),
				_point(x + 1, z, heights[i + 1] + shift),
				_point(x + 1, z + 1, heights[i + stride + 1] + shift),
				_point(x, z + 1, heights[i + stride] + shift))

	surface.set_smooth_group(-1)
	for x in range(columns):
		var far := rows * stride + x
		_wall(surface, _point(x, 0, heights[x] + shift),
			_point(x + 1, 0, heights[x + 1] + shift), bottom)
		_wall(surface, _point(x + 1, rows, heights[far + 1] + shift),
			_point(x, rows, heights[far] + shift), bottom)
	for z in range(rows):
		var left := z * stride
		var right := left + columns
		_wall(surface, _point(0, z + 1, heights[left + stride] + shift),
			_point(0, z, heights[left] + shift), bottom)
		_wall(surface, _point(columns, z, heights[right] + shift),
			_point(columns, z + 1, heights[right + stride] + shift), bottom)
	_bottom(surface, bottom)


func _wall(surface: SurfaceTool, a: Vector3, b: Vector3, bottom: float) -> void:
	_quad(surface, a, Vector3(a.x, bottom, a.z), Vector3(b.x, bottom, b.z), b)


func _bottom(surface: SurfaceTool, height: float) -> void:
	_quad(surface, _point(0, 0, height), _point(0, rows, height),
		_point(columns, rows, height), _point(columns, 0, height))


func _sample_height(noise: FastNoiseLite, x: float, z: float) -> float:
	var local_x := (x - columns * 0.5) * block_size
	var local_z := (z - rows * 0.5) * block_size
	var normalized := clampf((noise.get_noise_2d(local_x, local_z) + 1.0) * 0.5, 0.0, 1.0)
	return normalized * max_high


func _point(x: int, z: int, height: float) -> Vector3:
	return Vector3((x - columns * 0.5) * block_size, height, (z - rows * 0.5) * block_size)


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(d)
