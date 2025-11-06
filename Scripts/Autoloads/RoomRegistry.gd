extends Node

var room_definitions: Dictionary = {}
var rooms_by_type: Dictionary = {}

func _ready():
	load_room_definitions()

func load_room_definitions():
	print("Loading room definitions...")
	
	# Manually register room definitions (for now)
	# Later you can scan a folder for .tres files automatically
	register_room_definition("starter", preload("res://Resources/Rooms/starter.tres"))
	register_room_definition("basic_tresure", preload("res://Resources/Rooms/basic_treasure.tres"))
	register_room_definition("basic_merchant", preload("res://Resources/Rooms/basic_merchant.tres"))
	register_room_definition("tomb_grave", preload("res://Resources/Rooms/tomb_grave.tres"))
	register_room_definition("tomb_altar", preload("res://Resources/Rooms/tomb_altar.tres"))	
	register_room_definition("royal_forge", preload("res://Resources/Rooms/royal_forge.tres"))
	register_room_definition("rare_merchant", preload("res://Resources/Rooms/rare_merchant.tres"))

	print("Loaded ", room_definitions.size(), " room definitions")

func register_room_definition(id: String, room_def: RoomDefinition):
	if room_def == null:
		push_warning("Failed to load room definition: " + id)
		return
	
	room_definitions[id] = room_def
	
	# Also organize by room type for quick lookup
	if not rooms_by_type.has(room_def.room_type):
		rooms_by_type[room_def.room_type] = []
	rooms_by_type[room_def.room_type].append(room_def)
	
	print("Registered room: ", room_def.room_name, " (", id, ")")

func get_available_rooms_for_rank(rank: int) -> Array[RoomDefinition]:
	var available_rooms: Array[RoomDefinition] = []
	
	for room_def in room_definitions.values():
		if room_def.can_appear_at_rank(rank):
			available_rooms.append(room_def)
	
	return available_rooms

func get_room_definition(id: String) -> RoomDefinition:
	return room_definitions.get(id)

func get_room_definitions_by_type(room_type: Enums.RoomType) -> Array[RoomDefinition]:
	return rooms_by_type.get(room_type, [])

func get_all_room_definitions() -> Array[RoomDefinition]:
	var all_rooms: Array[RoomDefinition] = []
	for room_def in room_definitions.values():
		all_rooms.append(room_def)
	return all_rooms
