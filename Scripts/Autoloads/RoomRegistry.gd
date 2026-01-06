extends Node

var room_definitions: Dictionary = {}
var rooms_by_type: Dictionary = {}

func _ready():
	get_all_files_from_directory("res://Resources/Rooms/", ".tres")


func get_all_files_from_directory(path : String, file_ext:= "", files := []):
	var resources = ResourceLoader.list_directory(path)
	for res in resources:
		#print(str(path+res))
		if file_ext && res.ends_with(file_ext): 
			files.append(path+res)
			var room = load(path+res) as RoomDefinition
			
			if room:
				var key: String = res.replace(".tres", "")
				room_definitions[key] = room
				#print("Loaded room: ", key)
			else:
				push_warning("[RoomRegistry] Failed to load room: " + res)			
	return files

func register_room_definition(id: String, room_def: RoomDefinition):
	if room_def == null:
		push_warning("[RoomRegistry] Failed to load room definition: " + id)
		return
	
	room_definitions[id] = room_def
	
	# Also organize by room type for quick lookup
	if not rooms_by_type.has(room_def.room_type):
		rooms_by_type[room_def.room_type] = []
	rooms_by_type[room_def.room_type].append(room_def)
	
	print("[RoomRegistry] Registered room: ", room_def.room_name, " (", id, ")")

func get_available_rooms_for_rank(rank: int) -> Array[RoomDefinition]:
	var available_rooms: Array[RoomDefinition] = []
	
	for room_def in room_definitions.values():
		if room_def.can_appear_at_rank(rank):
			available_rooms.append(room_def)
	
	return available_rooms

func get_room_by_id(_id: String) -> RoomDefinition:
	if !room_definitions[_id]:
		return null
	return room_definitions[_id] 

func get_room_definition(id: String) -> RoomDefinition:
	return room_definitions.get(id)

func get_room_definitions_by_type(room_type: Enums.RoomType) -> Array[RoomDefinition]:
	return rooms_by_type.get(room_type, [])

func get_all_room_definitions() -> Array[RoomDefinition]:
	var all_rooms: Array[RoomDefinition] = []
	for room_def in room_definitions.values():
		all_rooms.append(room_def)
	return all_rooms

func get_rooms_by_type_and_rarity(type: Enums.RoomType, rarity: Enums.Rarity) -> Array[RoomDefinition]:
	# Get all room definitions matching specific type and rarity
	# Used for guaranteed room placements
	var results: Array[RoomDefinition] = []
	
	for room_def in room_definitions.values():
		if room_def.room_type == type and room_def.rarity == rarity:
			results.append(room_def)
	
	return results

func get_rooms_by_type(type: Enums.RoomType) -> Array[RoomDefinition]:
	# Get all room definitions matching specific type (any rarity)
	# Useful for flexible guaranteed placements
	var results: Array[RoomDefinition] = []
	
	for room_def in room_definitions.values():
		if room_def.room_type == type:
			results.append(room_def)
	
	return results

func get_rooms_by_type_rarity_and_rank(type: Enums.RoomType, rarity: Enums.Rarity, rank: int) -> Array[RoomDefinition]:
	# Get rooms matching type, rarity, AND valid for current rank
	# Most strict filter for guaranteed rooms
	var results: Array[RoomDefinition] = []
	
	for room_def in room_definitions.values():
		if room_def.room_type == type and room_def.rarity == rarity:
			if room_def.can_appear_at_rank(rank):
				results.append(room_def)
	
	return results
