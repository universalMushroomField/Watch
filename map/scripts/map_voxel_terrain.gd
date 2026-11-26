@tool
## 将高度场烘焙成有实体断面的地形。所有尺寸、采样和顶点都使用源模型的局部坐标。
class_name MapVoxelTerrain
extends RefCounted

const MAX_AXIS_CELLS := 128
const MAX_TOTAL_CELLS := 260_000
const DETACHED := 255
const DIRECTIONS: Array[Vector3i] = [
	Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN,
	Vector3i.BACK, Vector3i.FORWARD,
]
const QUAD_INDICES: Array[int] = [0, 2, 1, 0, 3, 2]

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()

var _rim_weights := PackedFloat32Array()
var _corner_profiles := PackedVector3Array()
var _dimensions: Vector3i
var _seed: int


static func build(source: MapSurfaceSampler, voxel_size: float, erosion: float, seed: int,
		intact_depth: float = 0.16, cluster_size: float = 2.4) -> ArrayMesh:
	var bounds := source.bounds
	if not bounds.has_volume():
		return null
	var size := maxf(voxel_size, bounds.size[bounds.size.max_axis_index()] / MAX_AXIS_CELLS)
	var dimensions := Vector3i((bounds.size / size).ceil()).maxi(1)
	while dimensions.x * dimensions.y * dimensions.z > MAX_TOTAL_CELLS:
		size *= 1.1
		dimensions = Vector3i((bounds.size / size).ceil()).maxi(1)
	# 平分模型的包围盒，最外圈不会产生一条极薄的残格。
	var pitch := bounds.size / Vector3(dimensions)
	var builder := MapVoxelTerrain.new()
	builder._dimensions = dimensions
	builder._seed = seed
	var cells := builder._fill_columns(source, dimensions, pitch, clampf(erosion, 0.0, 1.0),
		clampf(intact_depth, 0.0, 1.0), maxf(cluster_size, size), seed)
	return builder._build_mesh(cells, bounds.position, dimensions, pitch)


func _fill_columns(source: MapSurfaceSampler, dimensions: Vector3i, pitch: Vector3,
		erosion: float, intact_depth: float, cluster_size: float, seed: int) -> PackedByteArray:
	# 0 是空气，1..254 编码岩层深度，255 是与相邻面之间留有空隙的碎块。
	var cells := PackedByteArray()
	cells.resize(dimensions.x * dimensions.y * dimensions.z)
	var rock := FastNoiseLite.new()
	rock.seed = seed
	rock.noise_type = FastNoiseLite.TYPE_SIMPLEX
	rock.fractal_octaves = 2
	rock.frequency = 1.0 / cluster_size
	# 从格点直接查取细节。调整保留层时，其他格点仍使用相同的岩质。
	var grain := FastNoiseLite.new()
	grain.seed = seed ^ 0x3d2b91
	grain.noise_type = FastNoiseLite.TYPE_VALUE
	grain.fractal_type = FastNoiseLite.FRACTAL_NONE
	grain.frequency = 1.0
	var origin := source.bounds.position
	var tops := PackedInt32Array()
	var eroded_tops := PackedInt32Array()
	var distances := PackedInt32Array()
	tops.resize(dimensions.x * dimensions.z)
	eroded_tops.resize(tops.size())
	distances.resize(tops.size())
	for z in range(dimensions.z):
		for x in range(dimensions.x):
			var column := z * dimensions.x + x
			var center := Vector2(origin.x + (x + 0.5) * pitch.x, origin.z + (z + 0.5) * pitch.z)
			var height := source.height_at(center)
			if height == -INF:
				distances[column] = -1
				continue
			tops[column] = clampi(roundi((height - origin.y) / pitch.y), 1, dimensions.y)
			distances[column] = mini(mini(x, dimensions.x - 1 - x), mini(z, dimensions.z - 1 - z))
	# 两次扫描得到到轮廓的格距，凹边和空列也会形成崖岸。
	for i in range(tops.size()):
		if i % dimensions.x > 0:
			distances[i] = mini(distances[i], distances[i - 1] + 1)
		if i >= dimensions.x:
			distances[i] = mini(distances[i], distances[i - dimensions.x] + 1)
	for i in range(tops.size() - 1, -1, -1):
		if i % dimensions.x < dimensions.x - 1:
			distances[i] = mini(distances[i], distances[i + 1] + 1)
		if i + dimensions.x < tops.size():
			distances[i] = mini(distances[i], distances[i + dimensions.x] + 1)

	var rim_width := maxf(2.0, minf(dimensions.x, dimensions.z) * 0.15)
	_rim_weights.resize(tops.size())
	for z in range(dimensions.z):
		for x in range(dimensions.x):
			var column := z * dimensions.x + x
			var full_height := tops[column]
			if full_height == 0:
				continue
			var center := Vector2(origin.x + (x + 0.5) * pitch.x, origin.z + (z + 0.5) * pitch.z)
			var ridge := clampf(0.5 + rock.get_noise_2d(center.x, center.y), 0.0, 1.0)
			var rim := 1.0 - smoothstep(0.0, rim_width, float(distances[column]))
			if rim <= 0.0 or erosion <= 0.0:
				eroded_tops[column] = full_height
				for y in range(full_height):
					cells[_index(Vector3i(x, y, z), dimensions)] = 1 + roundi(253.0 * (full_height - 1 - y) / maxi(1, full_height - 1))
				continue
			_rim_weights[column] = rim * erosion
			var collapse := erosion * rim * (1.0 - intact_depth)
			var top := maxi(1, full_height - roundi(full_height * collapse * lerpf(0.48, 0.92, ridge)))
			eroded_tops[column] = top
			var removed := full_height - top
			for y in range(top):
				var depth := float(full_height - 1 - y) / maxi(1, full_height - 1)
				if y < top - 1 and collapse > 0.0 and depth > intact_depth:
					# 成片的岩层先产生孔洞。深处加入小尺度扰动，让岩桥断为碎块。
					var fracture := smoothstep(intact_depth, 1.0, depth)
					var strata := rock.get_noise_3d(center.x, origin.y + (y + 0.5) * pitch.y, center.y)
					var detail := lerpf(strata, grain.get_noise_3d(x, y, z), 0.32 * fracture)
					var strength := clampf(0.5 + 0.8 * detail, 0.0, 1.0)
					if strength < erosion * rim * fracture:
						removed += 1
						continue
				cells[_index(Vector3i(x, y, z), dimensions)] = 1 + roundi(253.0 * depth)
			# 崖脚从底向上堆实，堆高取决于剥落量及沿岸成簇的岩质。
			var pile := mini(top, roundi(removed * lerpf(0.15, 0.70, ridge)))
			for y in range(pile):
				cells[_index(Vector3i(x, y, z), dimensions)] = 1 + roundi(253.0 * (full_height - 1 - y) / maxi(1, full_height - 1))
			# 堆积完成后再剥离底面和崖边的局部岩粒，避免回填把碎块重新连成整片。
			for y in range(top - 1):
				var depth := float(full_height - 1 - y) / maxi(1, full_height - 1)
				var exposure := rim * rim
				if depth <= intact_depth:
					continue
				var density := 0.14 if y == 0 else 0.65
				var chance := erosion * exposure * smoothstep(intact_depth, 1.0, depth) * density
				var index := _index(Vector3i(x, y, z), dimensions)
				if cells[index] != 0 and (grain.get_noise_3d(x, y, z) + 1.0) * 0.5 < chance:
					cells[index] = DETACHED
	_build_corner_profiles(source, pitch, tops, eroded_tops)
	return cells


## Collapse one-cell stair risers onto a common sampled slope. Larger cliffs stay vertical.
func _build_corner_profiles(source: MapSurfaceSampler, pitch: Vector3,
		tops: PackedInt32Array, eroded_tops: PackedInt32Array) -> void:
	_corner_profiles.resize((_dimensions.x + 1) * (_dimensions.z + 1))
	var origin := source.bounds.position
	for z in range(_dimensions.z + 1):
		for x in range(_dimensions.x + 1):
			var lowest := _dimensions.y
			var highest := 0
			var removed := 0
			var count := 0
			for nz in range(maxi(0, z - 1), mini(_dimensions.z, z + 1)):
				for nx in range(maxi(0, x - 1), mini(_dimensions.x, x + 1)):
					var index := nz * _dimensions.x + nx
					var top := eroded_tops[index]
					if top == 0:
						continue
					lowest = mini(lowest, top)
					highest = maxi(highest, top)
					removed += tops[index] - top
					count += 1
			if count == 0 or highest - lowest > 1:
				continue
			var height := source.height_at(Vector2(origin.x + x * pitch.x, origin.z + z * pitch.z))
			if height == -INF:
				continue
			var target := (height - origin.y) / pitch.y - float(removed) / count
			target = clampf(target, maxf(0.25, lowest - 0.95), highest + 0.95)
			_corner_profiles[z * (_dimensions.x + 1) + x] = Vector3(lowest, highest, target)


static func _index(cell: Vector3i, dimensions: Vector3i) -> int:
	return (cell.z * dimensions.y + cell.y) * dimensions.x + cell.x


func _build_mesh(cells: PackedByteArray, origin: Vector3, dimensions: Vector3i,
		pitch: Vector3) -> ArrayMesh:
	var last := dimensions - Vector3i.ONE
	for z in range(dimensions.z):
		for y in range(dimensions.y):
			for x in range(dimensions.x):
				var cell := Vector3i(x, y, z)
				var material_depth := cells[_index(cell, dimensions)]
				if material_depth == 0:
					continue
				var center := Vector3(cell) + Vector3.ONE * 0.5
				var exposed: Array[Vector3i] = []
				var detached := material_depth == DETACHED
				for direction in DIRECTIONS:
					var neighbor := cell + direction
					if not detached and neighbor == neighbor.clamp(Vector3i.ZERO, last):
						var adjacent := cells[_index(neighbor, dimensions)]
						if adjacent != 0 and adjacent != DETACHED:
							continue
					exposed.append(direction)
				# 仅六面都露出的深层碎石可以移动。相邻岩块保持严丝合缝。
				var loose := exposed.size() == 6 and detached
				var phase := float(hash(cell) % 251) / 251.0
				var color := Color(minf(1.0, (material_depth - 1) / 253.0), float(loose), phase)
				var scale_factor := lerpf(0.45, 0.76, phase) if detached else 1.0
				if detached and y == 0:
					center.y -= 0.55 + phase * 0.65
				for direction in exposed:
					_add_face(center, Vector3(direction), origin, pitch, color, scale_factor, cell, detached)
	if _vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _add_face(center: Vector3, normal: Vector3, origin: Vector3, pitch: Vector3,
		color: Color, scale_factor: float, cell: Vector3i, detached: bool) -> void:
	var tangent := Vector3.UP if normal.y == 0.0 else Vector3.RIGHT
	var bitangent := normal.cross(tangent)
	var face_center := center + 0.5 * scale_factor * normal
	var u := 0.5 * scale_factor * tangent
	var v := 0.5 * scale_factor * bitangent
	var points := PackedVector3Array([
		face_center - u - v, face_center + u - v,
		face_center + u + v, face_center - u + v,
	])
	var tilt := Basis.IDENTITY
	if detached:
		tilt = Basis.from_euler(Vector3(
			_signed_hash(cell, 1), _signed_hash(cell, 2), _signed_hash(cell, 3)) * 0.65)
	for i in range(points.size()):
		var point := points[i]
		if detached:
			var corner_sign := Vector3i(((point - center) / scale_factor * 2.0).round())
			var stretch := 1.0 + _signed_hash(cell + corner_sign, 4) * 0.18
			point = center + tilt * ((point - center) * stretch)
		else:
			# Shared corners receive the same displacement, keeping adjacent faces sealed.
			point = _warp_corner(Vector3i(point.round()))
		points[i] = origin + point * pitch
	for i in range(0, QUAD_INDICES.size(), 3):
		var a := points[QUAD_INDICES[i]]
		var b := points[QUAD_INDICES[i + 1]]
		var c := points[QUAD_INDICES[i + 2]]
		var face_normal := (c - a).cross(b - a).normalized()
		if face_normal == Vector3.ZERO:
			continue
		for vertex in [a, b, c]:
			_vertices.append(vertex)
			_normals.append(face_normal)
			_colors.append(color)


func _warp_corner(corner: Vector3i) -> Vector3:
	var weight := 0.0
	for z in range(maxi(0, corner.z - 1), mini(_dimensions.z, corner.z + 1)):
		for x in range(maxi(0, corner.x - 1), mini(_dimensions.x, corner.x + 1)):
			weight += _rim_weights[z * _dimensions.x + x] * 0.25
	var column_corner := Vector3i(corner.x, 0, corner.z)
	var offset := Vector3(_signed_hash(column_corner, 5), 0.0, _signed_hash(column_corner, 6))
	var point := Vector3(corner) + offset * weight * 0.65
	var profile := _corner_profiles[corner.z * (_dimensions.x + 1) + corner.x]
	if profile.x > 0.0:
		if point.y < profile.x:
			point.y *= profile.z / profile.x
		else:
			point.y = profile.z + maxf(0.0, point.y - profile.y)
	return point


func _signed_hash(cell: Vector3i, salt: int) -> float:
	return float(hash(Vector4i(cell.x, cell.y, cell.z, _seed ^ salt)) % 1021) / 510.0 - 1.0
