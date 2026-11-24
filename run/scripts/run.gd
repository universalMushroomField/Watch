## 单局管理器类，持有种子、地图、玩家等等。
##
## 这个节点是一局游戏的根：它从 [SeedGenerator] 取本局种子，创建 [MapRun] 和
## [MapPlayerState]，地图视图只负责显示它。后续接入战斗时，在这里切换
## [member fight_system] 与地图视图的可见性即可。
class_name RunState
extends Node2D

## 本局种子。为 0 时在初始化阶段从 SeedGenerator 取当前单局种子。
@export var run_seed: int = 0
## 地图生成参数，留空时使用默认配置。
@export var map_config: MapConfig
## 本局使用的角色卡组，会在开局时复制一份。
@export var starting_deck: CardDeck
## 玩家初始生命上限。
@export var max_health: int = 70
## 玩家初始金币。
@export var starting_gold: int = 50
## 战斗场景，供后续从地图进入战斗时使用。
@export var fight_system: BaseFightScene
## 玩家角色，存在时优先使用它自己的卡组。
@export var player_character: CharacterSelectable

## 当前这一局的地图进度。
var map: MapRun
## 当前玩家的局内状态（生命、金币、卡组）。
var player: MapPlayerState


func _ready() -> void:
	_ensure_seed()
	if map_config == null:
		map_config = MapConfig.new()


## 初始化单局：用本局种子和给定棋盘布局创建地图。
## [param layout] 由地图视图根据地形和相机可视范围拟合。
func create_map(layout: HexLayout) -> MapRun:
	if layout == null:
		push_error("创建地图前必须提供拟合后的棋盘布局。")
		return null
	_ensure_seed()
	if map_config == null:
		map_config = MapConfig.new()
	if player == null:
		var deck := starting_deck
		if player_character != null and player_character.deck != null:
			deck = player_character.deck
		player = MapPlayerState.new(max_health, starting_gold, deck)
	map = MapRun.new(map_config, player, run_seed, layout)
	return map


## 从存档读取单局。存档格式未定，先保留入口。
func load_run(_path: String) -> bool:
	return false


## 确保本局种子已经确定：优先用场景里指定的值，否则取全局种子生成器。
func _ensure_seed() -> void:
	if run_seed != 0:
		return
	var generator := get_node_or_null("/root/SeedGenerator")
	if generator != null:
		run_seed = int(generator.get("run_seed"))
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system())
