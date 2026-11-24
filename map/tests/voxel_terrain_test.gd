extends SceneTree

const SEED_VALUE := 73
const VOXEL_SIZE := 1.0
const EROSION := 0.8

var failures := 0


func _initialize() -> void:
	# 左右两块高地分别厚 6 和 12 格，用来区分按局部埋深和按绝对高度侵蚀。
	var source_mesh := SurfaceTool.new()
	source_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(2):
		var box := BoxMesh.new()
		box.size = Vector3(16, 6 * (i + 1), 16)
		var center := Vector3(16 * i - 8, box.size.y * 0.5, 0)
		source_mesh.append_from(box, 0, Transform3D(Basis.IDENTITY, center))
	var source := MapSurfaceSampler.new()
	source.build_mesh(source_mesh.commit())
	var solid := MapVoxelTerrain.build(source, VOXEL_SIZE, 0.0, SEED_VALUE)
	var eroded := MapVoxelTerrain.build(source, VOXEL_SIZE, EROSION, SEED_VALUE)
	if solid == null or eroded == null:
		printerr("FAIL - 未能生成地形")
		quit(1)
		return

	# 上下表面、前后阶梯、左右端面以及台阶侧面。
	var exterior_area := 2.0 * 32 * 16 + 2.0 * 16 * (6 + 12) + 16 * (6 + 12 + 6)
	var solid_faces := solid.get_faces()
	var area := 0.0
	for i in range(0, solid_faces.size(), 3):
		area += (solid_faces[i + 1] - solid_faces[i]).cross(solid_faces[i + 2] - solid_faces[i]).length() * 0.5
	_check(is_equal_approx(area, exterior_area), "关闭侵蚀时实体仅有外表面")
	var arrays := solid.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var top_vertices := 0
	var bottom_vertices := 0
	var valid_depth := colors.size() == vertices.size()
	if valid_depth:
		for i in range(vertices.size()):
			if normals[i].y > 0.9:
				top_vertices += 1
				valid_depth = valid_depth and is_zero_approx(colors[i].r)
			elif normals[i].y < -0.9:
				bottom_vertices += 1
				valid_depth = valid_depth and colors[i].r > 0.8
	_check(valid_depth and top_vertices > 0 and bottom_vertices > 0, "两级地表及其底面分别使用浅层和深层色阶")

	var faces := eroded.get_faces()
	var fragments := eroded.surface_get_arrays(0)
	var positions: PackedVector3Array = fragments[Mesh.ARRAY_VERTEX]
	var flags: PackedColorArray = fragments[Mesh.ARRAY_COLOR]
	var underside := false
	var sides := 0
	for i in range(positions.size()):
		if flags[i].g < 0.5:
			continue
		var p := positions[i]
		if p.y < 0.0 and absf(p.x) < 12 and absf(p.z) < 5:
			underside = true
		if p.y > 1.0:
			if p.x < -14: sides |= 1
			if p.x > 14: sides |= 2
			if p.z < -6: sides |= 4
			if p.z > 6: sides |= 8
	_check(underside and sides == 15, "底面下方和四边都有独立的动态碎块")
	var repeat := MapVoxelTerrain.build(source, VOXEL_SIZE, EROSION, SEED_VALUE)
	_check(faces == repeat.get_faces(), "同种子生成相同碎块")
	var other := MapVoxelTerrain.build(source, VOXEL_SIZE, EROSION, SEED_VALUE + 1)
	_check(faces != other.get_faces(), "更换种子会改变碎块")
	var surface := MapSurfaceSampler.new()
	surface.build_mesh(eroded)
	for i in range(2):
		var height := 6.0 * (i + 1)
		var upper := _section_area(faces, i, height - 0.5)
		var lower := _section_area(faces, i, 0.5)
		var center_x := -8.5 + 16.0 * i
		_check(is_equal_approx(surface.height_at(Vector2(center_x, 0.5)), height), "内部地表高度保留")
		for point in [Vector2(center_x, -7.5), Vector2(center_x, 7.5), Vector2(-15.5 + 31 * i, 0.5)]:
			var rim_height := surface.height_at(point)
			_check(rim_height > 0.0 and rim_height < height, "四周边缘向下形成台阶")
		_check(lower > upper, "崖脚堆积的覆盖范围大于完整上层")
	print("VOXEL TERRAIN TEST ", "PASSED" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)


## 累计切面上方水平三角形的有向投影面积，得到闭合体素在该高度的实体截面积。
func _section_area(faces: PackedVector3Array, half: int, height: float) -> float:
	var area := 0.0
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		if a.y <= height or a.y != b.y or a.y != c.y:
			continue
		var center_x := (a.x + b.x + c.x) / 3.0
		if (half == 0) == (center_x < 0.0):
			area += (c - a).cross(b - a).y * 0.5
	return area


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok - ", message)
	else:
		failures += 1
		printerr("  FAIL - ", message)
