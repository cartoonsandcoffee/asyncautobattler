extends Node

var hallway_definitions: Dictionary = {}

func _ready():
	_load_hallway_definitions()

func _load_hallway_definitions():
	var hallway_dir = "res://Resources/Hallways/"
	var dir = DirAccess.open(hallway_dir)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var hallway_path = hallway_dir + file_name
				var hallway = load(hallway_path) as HallwayDefinition
				
				if hallway:
					var key = file_name.replace(".tres", "")
					hallway_definitions[key] = hallway
					print("Loaded hallway: ", key)
				else:
					push_warning("Failed to load hallway: " + file_name)
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	else:
		push_error("Could not open hallway directory: " + hallway_dir)

func get_hallway_definition(key: String) -> HallwayDefinition:
	if hallway_definitions.has(key):
		return hallway_definitions[key]
	else:
		push_warning("Hallway definition not found: " + key)
		return null

func get_available_hallways_for_rank(rank: int) -> Array[HallwayDefinition]:
	var available: Array[HallwayDefinition] = []
	
	for key in hallway_definitions:
		var hallway = hallway_definitions[key]
		if hallway.can_appear_at_rank(rank):
			available.append(hallway)
	
	return available

func get_available_hallways_for_position(rank: int, position: int) -> Array[HallwayDefinition]:
	var available: Array[HallwayDefinition] = []
	
	for key in hallway_definitions:
		var hallway = hallway_definitions[key]
		if hallway.can_appear_at_rank(rank) and hallway.can_appear_at_position(position):
			available.append(hallway)
	
	return available