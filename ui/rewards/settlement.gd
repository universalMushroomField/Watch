extends ColorRect

signal departed
const BUTTON := preload("res://ui/rewards/reward_button.tscn")
const AMBER := preload("res://public/meshs/living_amber.tscn")
const TAG := preload("res://collections/templates/watch_tag.tscn")
const POOL := preload("res://map/res/data/map_content_pool.tres")

const CARD_PITCH := 278.0
var moving_cards: Array[Button] = []
var starts: Array[float] = []
var ends: Array[float] = []
var slide_progress := 0.0:
	set(value):
		slide_progress = value
		for i in moving_cards.size():
			var fraction := smoothstep(0.12 * i, 0.76 + 0.12 * i, value)
			moving_cards[i].position.x = lerpf(starts[i], ends[i], fraction)

func _close_gap() -> void:
	# 保留正在播放的实际位置，避免停止动画时重新采样旧起点。
	$Motion.stop(true)
	moving_cards.clear()
	starts.clear()
	ends.clear()
	var slot := 0
	for button in %Rewards.get_children():
		if not button.visible:
			continue
		var target := slot * CARD_PITCH
		if not is_equal_approx(button.position.x, target):
			moving_cards.append(button)
			starts.append(button.position.x)
			ends.append(target)
		slot += 1
	if not moving_cards.is_empty():
		$Motion.play("slide")
	if slot == 0:
		%Leave.grab_focus()

func populate(player: RunPlayerState, encounter_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = encounter_seed
	var amount := rng.randi_range(POOL.battle_gold_min, POOL.battle_gold_max)
	_offer("物资", "活性精珀 × %d" % amount, AMBER, player.add_gold.bind(amount))
	if not player.deck.reward_pool.is_empty():
		var card := player.deck.reward_pool[rng.randi_range(0, player.deck.reward_pool.size()-1)]
		_offer("战术卡牌", card.display_name, null, player.add_card.bind(card), card)
	if not player.collectibles.has(TAG):
		_offer("收藏品", preload("res://collections/scripts/watch_tag.gd").DISPLAY_NAME, TAG, func(): player.collectibles.append(TAG))
	%Leave.pressed.connect(func(): departed.emit(), CONNECT_ONE_SHOT)
	%Rewards.get_child(0).grab_focus()

func _offer(category: String, title: String, scene: PackedScene, grant: Callable, card: CardData = null) -> void:
	var button = BUTTON.instantiate()
	button.position.x = %Rewards.get_child_count() * CARD_PITCH
	%Rewards.add_child(button)
	button.taken.connect(_close_gap)
	button.configure(category, title, scene, grant, card)
