extends Node

const SAVE_PATH := "res://Saves/game_save.json"

func save_game():
	var save_dict: Dictionary = {
		"player":          Player.to_dict()
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_dict, "\t"))   # pretty print
	file.close()
	print("Game saved!")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string := file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_string)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Save file corrupted.")
		return false

	Player.from_dict(data.player)

	print("Game loaded!")
	return true

func clear_save():
	if FileAccess.file_exists(SAVE_PATH):
		var error = DirAccess.remove_absolute(SAVE_PATH)
		if error != OK:
			print("Error deleting save file: ", error)
		else:
			print("Save file deleted successfully!")
	else:
		print("Save file not found at: ", SAVE_PATH)

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func resource_to_path(res: Resource) -> String:
	return res.resource_path if res and res.resource_path != "" else ""
