extends Node

signal show_minimap()
signal room_transition_requested(room_data: RoomData)
signal minimap_update_requested()

var current_rank: int = 1
var current_room_index: int = 1
var rooms_cleared_this_rank: int = 0
var number_of_doors: int = 3

var all_visited_rooms: Array[RoomData] = []
var current_rank_rooms: Array[RoomData] = []

func generate_door_choices() -> Array[RoomData]:
	var door_choices: Array[RoomData] = []
	
	# Get available room definitions for current rank
	var available_rooms = RoomRegistry.get_available_rooms_for_rank(current_rank)
	
	if available_rooms.size() == 0:
		push_error("No rooms available for rank " + str(current_rank))
		return door_choices
	
	# Generate 3 different room choices
	for i in number_of_doors:
		var room_def = pick_weighted_room_definition(available_rooms)
		var event_scene = room_def.get_random_event()
		
		var room_data = RoomData.new()
		room_data.room_definition = room_def  # Store reference to definition
		room_data.chosen_event_scene = event_scene   # Store the specific event
		
		door_choices.append(room_data)
		
		# Remove this room definition to avoid duplicates in this set of choices
		available_rooms.erase(room_def)
		
		# If we run out of room types, break (in case there are < 3 available)
		if available_rooms.size() == 0:
			break
	
	return door_choices

func pick_weighted_room_definition(available_rooms: Array[RoomDefinition]) -> RoomDefinition:
	#Pick a room definition based on spawn weights
	var weighted_options: Array[RoomDefinition] = []
	
	for room_def in available_rooms:
		var weight = room_def.spawn_weight
		for i in weight:
			weighted_options.append(room_def)
	
	return weighted_options.pick_random()


func generate_starter_room() -> RoomData:
	var starter_def = RoomRegistry.get_room_definition("starter")
	if starter_def == null:
		push_error("Starter room definition not found!")
		return null
	
	var room_data = RoomData.new()
	room_data.room_definition = starter_def
	room_data.chosen_event_scene = starter_def.get_random_event()  # Should be mysterious_old_man_event

	return room_data


func get_room_type_display_name(room_data: RoomData) -> String:
	if room_data.room_definition:
		return room_data.room_definition.room_name
	else:
		return "Unknown Room"

func get_room_type_icon(room_data: RoomData) -> Texture2D:
	if room_data.room_definition:
		return room_data.room_definition.door_icon
	else:
		return null

func advance_room(chosen_room: RoomData):
	current_room_index += 1
	rooms_cleared_this_rank += 1

	# Store room if provided
	if chosen_room:
		all_visited_rooms.append(chosen_room)
		current_rank_rooms.append(chosen_room)
		minimap_update_requested.emit()
			
	# Check if we've cleared 5 rooms (time for boss)
	if rooms_cleared_this_rank >= 6:
		advance_rank()
	
	print("Advanced to room ", current_room_index, " (", rooms_cleared_this_rank, "/6 this rank)")


func slide_in_menus():
	show_minimap.emit()

func advance_rank():
	current_rank += 1
	current_room_index = 1
	rooms_cleared_this_rank = 0
	current_rank_rooms.clear()
	minimap_update_requested.emit()
	print("Advanced to Rank ", current_rank)