extends Node

signal skin_selected(skin_id: int)
signal skin_unlocked(skin_id: int)

const SAVE_PATH = "user://skin_data.json"

# All skins defined here — add new skins to this list
var all_skins: Array[SkinData] = []

var unlocked_skin_ids: Array[int] = []
var selected_skin_id: int = 0

var _initialized: bool = false

func initialize():
	if _initialized:
		return
	_initialized = true

	load_all_skins()
	_load_local_data()


func _ready() -> void:
	pass

# ============================================
# SKIN REGISTRY
# ============================================

func load_all_skins():
	all_skins.clear()
	var dir = DirAccess.open("res://Resources/Skins/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var skin = load("res://Resources/Skins/" + file_name)
				if skin is SkinData:
					all_skins.append(skin)
			file_name = dir.get_next()

# ============================================
# LOCAL PERSISTENCE
# ============================================

func _load_local_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		unlocked_skin_ids = [0]  # Default always unlocked
		selected_skin_id = 0
		_save_local_data()
		return
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[SkinManager] Failed to open skin_data.json")
		return
	
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not parsed or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SkinManager] Corrupt skin_data.json, resetting")
		unlocked_skin_ids = [0]
		selected_skin_id = 0
		_save_local_data()
		return
	
	var raw: Array = parsed.get("unlocked", [0])
	unlocked_skin_ids.assign(raw)
	selected_skin_id  = parsed.get("selected", 0)
	
	# Ensure default is always unlocked
	if not 0 in unlocked_skin_ids:
		unlocked_skin_ids.append(0)
	
	print("[SkinManager] Loaded - selected: %d, unlocked: %s" % [selected_skin_id, str(unlocked_skin_ids)])

func _save_local_data() -> void:
	var data := {
		"unlocked": unlocked_skin_ids,
		"selected": selected_skin_id
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

# ============================================
# PUBLIC API
# ============================================

func is_unlocked(skin_id: int) -> bool:
	return skin_id in unlocked_skin_ids

func unlock_skin(skin_id: int) -> void:
	if not skin_id in unlocked_skin_ids:
		unlocked_skin_ids.append(skin_id)
		_save_local_data()
		skin_unlocked.emit(skin_id)
		print("[SkinManager] Unlocked skin %d" % skin_id)

func select_skin(skin_id: int) -> bool:
	"""Select a skin by id. Updates Player.skin_id and saves locally. Returns false if not unlocked."""
	if not is_unlocked(skin_id):
		push_warning("[SkinManager] Tried to select locked skin %d" % skin_id)
		return false
	
	selected_skin_id = skin_id
	Player.skin_id = skin_id
	_save_local_data()
	skin_selected.emit(skin_id)
	print("[SkinManager] Selected skin %d" % skin_id)
	return true

func get_skin(skin_id: int) -> SkinData:
	for s in all_skins:
		if s.skin_id == skin_id:
			return s
	return null

func get_selected_skin() -> SkinData:
	return get_skin(selected_skin_id)

func get_sprite_texture(skin_id: int) -> Texture2D:
	var s := get_skin(skin_id)
	if s and ResourceLoader.exists(s.sprite_path):
		return load(s.sprite_path)
	return null

func apply_selected_skin_to_player() -> void:
	"""Call this after Player autoload is ready to sync skin_id."""
	Player.skin_id = selected_skin_id
