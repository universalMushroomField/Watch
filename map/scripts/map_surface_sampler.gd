## 从真实三角网格查询世界 XZ 对应的最高地表交点。
class_name MapSurfaceSampler
extends RefCounted

const BIN_SIZE := 1.0
var bounds: AABB
var _triangles := PackedVector3Array()
var _bins := {}


func build(terrain: MeshInstance3D) -> void:
	_triangles.clear()
	_bins.clear()
	if terrain == null or terrain.mesh == null:
		bounds = AABB()
		return
	var transform := terrain.global_transform
	bounds = transform * terrain.mesh.get_aabb()
	var faces := terrain.mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var a := transform * faces[i]
		var b := transform * faces[i + 1]
		var c := transform * faces[i + 2]
		if (c - a).cross(b - a).y <= 0.000001:
			continue
		var index := _triangles.size()
		_triangles.append_array(PackedVector3Array([a, b, c]))
		var first := _bin(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var last := _bin(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		for z in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var key := Vector2i(x, z)
				if not _bins.has(key):
					_bins[key] = []
				_bins[key].append(index)


func height_at(point: Vector2) -> float:
	var height := -INF
	var origin := Vector3(point.x, bounds.end.y + 1.0, point.y)
	for index: int in _bins.get(_bin(point.x, point.y), []):
		var hit = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN,
			_triangles[index], _triangles[index + 1], _triangles[index + 2])
		if hit != null:
			height = maxf(height, hit.y)
	return height


## 按三角形边界切分地面路径，台阶处在同一 XZ 处连接两侧高度。
func trace(a: Vector3, b: Vector3) -> PackedVector3Array:
	var start := Vector2(a.x, a.z)
	var end := Vector2(b.x, b.z)
	var direction := end - start
	var length_squared := direction.length_squared()
	if length_squared <= 0.000001:
		return PackedVector3Array([a, b])
	var first := _bin(minf(start.x, end.x), minf(start.y, end.y))
	var last := _bin(maxf(start.x, end.x), maxf(start.y, end.y))
	var seen := {}
	var cuts: Array[float] = [0.0, 1.0]
	for z in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for index: int in _bins.get(Vector2i(x, z), []):
				if seen.has(index):
					continue
				seen[index] = true
				for i in range(3):
					var p := _triangles[index + i]
					var q := _triangles[index + (i + 1) % 3]
					var hit = Geometry2D.segment_intersects_segment(start, end, Vector2(p.x, p.z), Vector2(q.x, q.z))
					if hit != null:
						cuts.append(clampf((hit - start).dot(direction) / length_squared, 0.0, 1.0))
	cuts.sort()
	var path := PackedVector3Array([a])
	var previous := 0.0
	for cut in cuts:
		if cut - previous <= 0.000001:
			continue
		var p0 := start.lerp(end, previous)
		var p1 := start.lerp(end, cut)
		var y0 := height_at(p0.lerp(p1, 0.25))
		var y1 := height_at(p0.lerp(p1, 0.75))
		if y0 != -INF and y1 != -INF:
			var slope := (y1 - y0) * 0.5
			path.append(Vector3(p0.x, y0 - slope, p0.y))
			path.append(Vector3(p1.x, y1 + slope, p1.y))
		previous = cut
	path.append(b)
	return path


func _bin(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / BIN_SIZE), floori(z / BIN_SIZE))
