## 卡牌的序列类，维护核心机制[序列]

class_name CardSequence
extends RefCounted
## Index 0 is the top of the sequence (the most recently added symbol).


## 目前的两类符号，可以扩展
enum Symbol { ATTACK, DEFENSE }


## 序列数组
var _symbols: Array[Symbol] = []

## 获取序列数组的复制，主要是为了防止直接修改
func get_symbols() -> Array[Symbol]:
	return _symbols.duplicate()

## 向序列尾部追加一个symbol
func push(symbol: Symbol) -> void:
	_symbols.push_front(symbol)

## 清除序列
func clear() -> void:
	_symbols.clear()

## 返回所有对应子序列的下标
func find_pattern_positions(pattern: Array[Symbol]) -> Array[int]:
	return _find_pattern(pattern)


## 检查序列顶是否匹配子序列，从下标 0 开始比较。
func has_pattern_at_top(pattern: Array[Symbol]) -> bool:
	return can_consume(pattern, 0)


## 检查序列尾是否匹配子序列，要求匹配恰好在序列末尾结束。
func has_pattern_at_tail(pattern: Array[Symbol]) -> bool:
	var start := _symbols.size() - pattern.size()
	return start >= 0 and can_consume(pattern, start)


## 传入 -1表示检查序列的任意位置。
func can_consume(pattern: Array[Symbol], start: int = -1) -> bool:
	if start == -1:
		return pattern.is_empty() or not _find_pattern(pattern, true).is_empty()
	if start < 0 or start > _symbols.size() - pattern.size():
		return false
	for offset in range(pattern.size()):
		if _symbols[start + offset] != pattern[offset]:
			return false
	return true

## 消费掉列，传入-1表示从队头的第一个匹配位置
func consume(pattern: Array[Symbol], start: int = -1) -> bool:
	if start == -1:
		var positions := _find_pattern(pattern, true)
		if positions.is_empty():
			return false
		start = positions[0]
	elif not can_consume(pattern, start):
		return false
	for offset in range(pattern.size()):
		_symbols.remove_at(start)
	return true

###################采用了较为复杂的算法，如看不懂不要改 ######################
func _find_pattern(pattern: Array[Symbol], first_only: bool = false) -> Array[int]:
	var positions: Array[int] = []
	var length := pattern.size()
	var last_start := _symbols.size() - length
	if length == 0:
		for start in range(1 if first_only else last_start + 1):
			positions.append(start)
		return positions
	if last_start < 0:
		return positions

	# The later of the two maximal suffixes gives the critical split.
	var factor := _maximal_suffix(pattern, false)
	var reverse_factor := _maximal_suffix(pattern, true)
	if reverse_factor.x > factor.x:
		factor = reverse_factor
	var cut := factor.x + 1
	var shift := factor.y
	var overlap := length - shift
	for offset in range(cut):
		if pattern[offset] != pattern[offset + shift]:
			shift = maxi(cut - 1, length - cut) + 1
			overlap = 0
			break

	var start := 0
	var known_prefix := 0
	while start <= last_start:
		# Scan the right half first, then check the left half backwards.
		var offset := maxi(cut, known_prefix)
		while offset < length and pattern[offset] == _symbols[start + offset]:
			offset += 1
		if offset < length:
			start += offset - cut + 1
			known_prefix = 0
			continue

		offset = cut
		while offset > known_prefix and pattern[offset - 1] == _symbols[start + offset - 1]:
			offset -= 1
		if offset <= known_prefix:
			positions.append(start)
			if first_only:
				return positions

		start += shift
		# A period shift preserves this many already matched symbols.
		known_prefix = overlap
	return positions


# Returns the index before the maximal suffix and the suffix's period.
static func _maximal_suffix(pattern: Array[Symbol], reverse_order: bool) -> Vector2i:
	var suffix := -1
	var candidate := 0
	var offset := 1
	var period := 1
	while candidate + offset < pattern.size():
		var candidate_symbol := pattern[candidate + offset]
		var suffix_symbol := pattern[suffix + offset]
		if candidate_symbol == suffix_symbol:
			if offset == period:
				candidate += period
				offset = 1
			else:
				offset += 1
		elif (candidate_symbol < suffix_symbol) != reverse_order:
			candidate += offset
			offset = 1
			period = candidate - suffix
		else:
			suffix = candidate
			candidate += 1
			offset = 1
			period = 1
	return Vector2i(suffix, period)
