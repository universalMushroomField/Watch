extends SceneTree

## 临时脚本：渲染一张地图截图，用于人工检查布局。


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: PackedScene = load("res://map/templates/map_view.tscn")
	var view := scene.instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://map/tests/layout_preview.png")
	quit(0)
