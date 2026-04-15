extends Node

signal entry_added(text: String)

const MAX_ENTRIES := 100

var _entries: Array[String] = []


func log(text: String) -> void:
	_entries.append(text)
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()
	entry_added.emit(text)


func clear() -> void:
	_entries.clear()


func get_all() -> Array[String]:
	return _entries.duplicate()
