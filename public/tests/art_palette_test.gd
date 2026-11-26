extends SceneTree

## 色板检查：`public/color_palette_art.tres` 是美术限色的唯一真源，在编辑器里直接改。
##
##     godot --headless --path . -s res://public/tests/art_palette_test.gd
##
## 只查手改最容易出的两类低级错：色值重复、误填半透明。色数与明度分配由人工把握。

const TRES_PATH := "res://public/color_palette_art.tres"
## 像素画色板按不透明用，出现半透明说明误填了 alpha。
const OPAQUE_EPSILON := 0.001

var _failures: Array[String] = []


func _init() -> void:
	var palette := load(TRES_PATH) as ColorPalette
	_check(palette != null, "%s 能作为 ColorPalette 加载" % TRES_PATH)
	if palette == null:
		_report()
		return
	var colors := palette.colors
	_check_unique(colors)
	_check_opaque(colors)
	_report(colors)


func _check_unique(colors: PackedColorArray) -> void:
	var seen := {}
	for color in colors:
		var key := "%d,%d,%d" % [color.r8, color.g8, color.b8]
		_check(not seen.has(key), "色值重复：%s 出现两次" % color.to_html(false))
		seen[key] = true


func _check_opaque(colors: PackedColorArray) -> void:
	for color in colors:
		_check(
			absf(color.a - 1.0) <= OPAQUE_EPSILON,
			"%s 的 alpha 应为 1（实际 %.3f）" % [color.to_html(false), color.a]
		)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report(colors := PackedColorArray()) -> void:
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("art_palette_test 通过：%d 色，无重复色值、alpha 均为 1。" % colors.size())
	quit(0)
