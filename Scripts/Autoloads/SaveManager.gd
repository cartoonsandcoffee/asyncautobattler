extends Node

const SAVE_PATH := "user://run_save.json"

func save_run() -> void:
	"""Write current run state to disk. Call after every room and rank advance."""
	if Player.player_name.is_empty():
		push_warning("[SaveManager] save_run() called before player name set — skipping")
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Failed to open save file for writing")
		return
	file.store_string(JSON.stringify(Player.to_dict(), "\t"))
	file.close()
	print("[SaveManager] Run saved (Rank %d, rooms left: %d)" % [Player.current_rank, Player.rooms_left_this_rank])

func load_run() -> bool:
	"""Load saved run. Returns true if successful."""
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Failed to open save file for reading")
		return false
	var json_string := file.get_as_text()
	file.close()
	var data = JSON.parse_string(json_string)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[SaveManager] Save file corrupted or invalid JSON")
		return false
	Player.from_dict(data)
	DungeonManager.is_loaded_from_save = true
	print("[SaveManager] Run loaded (Rank %d)" % Player.current_rank)
	return true

func has_saved_run() -> bool:
	"""Use to show/hide Continue button on main menu."""
	return FileAccess.file_exists(SAVE_PATH)

func delete_saved_run() -> void:
	"""Call on run end (death, victory) and at start of new_run()."""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("[SaveManager] Save deleted")