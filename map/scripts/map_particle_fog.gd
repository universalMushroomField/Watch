@tool
extends MultiMeshInstance3D

func _validate_property(property: Dictionary) -> void:
	if property.name == &"multimesh":
		property.usage = PROPERTY_USAGE_NONE


## 沿实际地表分层撒点。实例位置在模型空间固定，流动由着色器计算。
func rebuild(terrain_mesh: Mesh, terrain_seed: int) -> void:
	var sampler := MapSurfaceSampler.new()
	sampler.build_mesh(terrain_mesh)
	var bounds := sampler.bounds
	var spacing := maxf(0.52, maxf(bounds.size.x, bounds.size.z) / 112.0)
	var columns := maxi(1, ceili(bounds.size.x / spacing))
	var rows := maxi(1, ceili(bounds.size.z / spacing))
	var pitch := Vector2(bounds.size.x / columns, bounds.size.z / rows)
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain_seed
	var positions := PackedVector3Array()
	var data := PackedColorArray()
	for z in range(rows):
		for x in range(columns):
			var px := bounds.position.x + (x + rng.randf_range(0.1, 0.9)) * pitch.x
			var pz := bounds.position.z + (z + rng.randf_range(0.1, 0.9)) * pitch.y
			var top := sampler.height_at(Vector2(px, pz))
			if top == -INF:
				continue
			var thickness := top - bounds.position.y
			var count := clampi(ceili(thickness / spacing), 2, 9)
			for i in range(count):
				var depth := pow((i + rng.randf()) / count, 2.8)
				positions.append(Vector3(px, top - thickness * depth, pz))
				var phase := fposmod(px * 0.045 + pz * 0.025 + 0.12 * rng.randf(), 1.0)
				data.append(Color(depth, rng.randf(), rng.randf(), phase))

	var cloud := MultiMesh.new()
	cloud.transform_format = MultiMesh.TRANSFORM_3D
	cloud.use_custom_data = true
	cloud.mesh = QuadMesh.new()
	cloud.instance_count = positions.size()
	for i in range(positions.size()):
		cloud.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
		cloud.set_instance_custom_data(i, data[i])
	cloud.custom_aabb = bounds.grow(3.0)
	multimesh = cloud
