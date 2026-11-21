class_name CardSequence
extends RefCounted
## Index 0 is the top of the sequence (the most recently added symbol).

enum Symbol { ATTACK, DEFENSE }

var _symbols: Array[Symbol] = []


func get_symbols() -> Array[Symbol]:
	return _symbols.duplicate()


func push(symbol: Symbol) -> void:
	_symbols.push_front(symbol)


func clear() -> void:
	_symbols.clear()


func can_consume(pattern: Array[Symbol]) -> bool:
	return pattern.is_empty() or _find_pattern(pattern) >= 0


func consume(pattern: Array[Symbol]) -> bool:
	if pattern.is_empty():
		return true
	var index := _find_pattern(pattern)
	if index < 0:
		return false
	for offset in range(pattern.size()):
		_symbols.remove_at(index)
	return true


func _find_pattern(pattern: Array[Symbol]) -> int:
	for start in range(_symbols.size() - pattern.size() + 1):
		var matches := true
		for offset in range(pattern.size()):
			if _symbols[start + offset] != pattern[offset]:
				matches = false
				break
		if matches:
			return start
	return -1
