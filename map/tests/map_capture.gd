extends SceneTree

## 临时脚本：渲染地图截图，用于人工检查布局与节点状态配色。


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: PackedScene = load("res://ui/gui_map/map_view.tscn")
	var view := scene.instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_save("res://map/tests/layout_preview.png")

	var layer: MapHexLayer = view._hex_layer
	var reachable: Array = view.run.get_reachable_nodes()
	if not reachable.is_empty():
		layer.set_hover_id(reachable[reachable.size() - 1].id)
		for i in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		_save("res://map/tests/layout_hover.png")
	quit(0)


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)