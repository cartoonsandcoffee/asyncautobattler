extends Node

signal path_unlocked(path_index: int)

const SAVE_PATH = "user://path_unlock_data_tst.json"

var unlocked_path_ids: Array[int] = [0, 1]
var pending_unlock_ids: Array[int] = []

var _initialized: bool = false

func initialize():
	if _initialized:
		return
	_initialized = true
	_load_local_data()

func _load_local_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		unlocked_path_ids = [0, 1]
		pending_unlock_ids = []
		_save_local_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[PathUnlockManager] Failed to open save file")
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if not parsed or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[PathUnlockManager] Corrupt save, resetting")
		unlocked_path_ids = [0, 1]
		pending_unlock_ids = []
		_save_local_data()
		return

	var raw: Array = parsed.get("unlocked", [0, 1])
	unlocked_path_ids.assign(raw)
	var raw_pending: Array = parsed.get("pending", [])
	pending_unlock_ids.assign(raw_pending)

	# Safety: 0 and 1 always unlocked
	for id in [0, 1]:
		if not id in unlocked_path_ids:
			unlocked_path_ids.append(id)

func _save_local_data() -> void:
	var data := { "unlocked": unlocked_path_ids, "pending": pending_unlock_ids }
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func is_path_unlocked(path_index: int) -> bool:
	return path_index in unlocked_path_ids

func unlock_path(path_index: int) -> void:
	if path_index in unlocked_path_ids:
		return
	unlocked_path_ids.append(path_index)
	if not path_index in pending_unlock_ids:
		pending_unlock_ids.append(path_index)
	_save_local_data()
	path_unlocked.emit(path_index)

func consume_pending_unlocks() -> Array[int]:
	var result: Array[int] = []
	result.assign(pending_unlock_ids)
	pending_unlock_ids.clear()
	_save_local_data()
	return result