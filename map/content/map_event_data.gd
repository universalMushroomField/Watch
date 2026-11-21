## 一个未知事件：标题、正文和若干选项。
class_name MapEventData
extends Resource

## 事件标识，方便日志和后续存档引用。
@export var id: StringName
## 事件标题。
@export var title: String = "未知事件"
## 事件正文。
@export_multiline var body: String = ""
## 玩家可选的选项。
@export var choices: Array[MapEventChoice] = []
