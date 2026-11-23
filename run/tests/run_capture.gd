extends SceneTree

## 临时脚本：从真正的单局入口渲染一张截图，用于人工检查地图布局。


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene: PackedScene = load("res://run/templates/run.tscn")
	var run := scene.instantiate()
	root.add_child(run)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://run/tests/run_preview.png")
	quit(0)