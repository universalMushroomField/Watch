class_name SeedGenerator
extends RefCounted

## 基于当前时间生成一局游戏使用的种子。
##
## [param salt] 用于区分不同模式、关卡或重开轮次；传空则只依赖时间。
static func generate_run_seed(salt: String = "") -> int:
	var time := Time.get_datetime_dict_from_system(true)

	# 精确到纳秒；混入库版本、进程 ID 与调用序号，降低同毫秒连续启动的碰撞概率。
	var sequence := _next_sequence()
	var raw := "%d|%04d-%02d-%02d %02d:%02d:%02d.%09d|%s|%d|%d|%d" % [
		OS.get_process_id(),
		time["year"], time["month"], time["day"],
		time["hour"], time["minute"], time["second"],
		time["nanosecond"],
		salt,
		sequence,
		Engine.get_version_info()["hex"],
		hash(OS.get_unique_id())
	]

	var seed_value := absi(hash(raw))
	if seed_value == 0:
		seed_value = 1
	return seed_value


## 创建本局专用的确定性随机数发生器。
static func create_run_rng(salt: String = "") -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = generate_run_seed(salt)
	return rng


## 从主种子派生一个具名子种子。
## 例如 "draw"、"enemy"、"map"，确保各系统随机序列互不干扰。
static func derive_seed(root_seed: int, domain: StringName) -> int:
	var derived := absi(hash("%d|%s" % [root_seed, domain]))
	return derived if derived != 0 else 1


## 创建具名子系统的 RNG。
static func create_derived_rng(root_seed: int, domain: StringName) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(root_seed, domain)
	return rng


## 生成便于展示和复现的短种子，例如 "K7M2-9QPL"。
static func format_seed(seed_value: int, group_size: int = 4) -> String:
	var alphabet := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var value := absi(seed_value)
	var chars := PackedStringArray()

	while value > 0 or chars.size() < group_size:
		chars.append(alphabet[value % alphabet.length()])
		value /= alphabet.length()

	chars.reverse()
	var text := "".join(chars)
	if text.length() > group_size:
		return text.substr(0, group_size) + "-" + text.substr(group_size)
	return text


static var _sequence_counter: int = 0

static func _next_sequence() -> int:
	_sequence_counter += 1
	return _sequence_counter
