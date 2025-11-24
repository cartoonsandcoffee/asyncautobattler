extends Node

signal show_minimap()
signal room_transition_requested(room_data: RoomData)
signal minimap_update_requested()

var current_rank: int = 1
var current_room_index: int = 1
var rooms_cleared_this_rank: int = 0
var number_of_doors: int = 3

var current_rank_hallways: Array[HallwayDefinition] = []  # 5 predetermined hallways
var all_visited_hallways: Array[HallwayDefinition] = []
var current_rank_visited_hallways: Array[HallwayDefinition] = []

var current_hallway_index: int = 0  # Which hallway we're on (0-4)
var awaiting_hallway: bool = false  # Are we between door selection and hallway completion?

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

	# Generate hallways for rank 1
	generate_rank_hallways()

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
	# Room selected but not entered yet - we're about to enter hallway
	awaiting_hallway = true

	current_room_index += 1
	rooms_cleared_this_rank += 1

	# Store room if provided
	if chosen_room:
		all_visited_rooms.append(chosen_room)
		current_rank_rooms.append(chosen_room)
		minimap_update_requested.emit()
			
	# -- Check if we've cleared 5 rooms (time for boss)
	#if rooms_cleared_this_rank >= 6:
	#	advance_rank()
	
	print("Advanced to room ", current_room_index, " (", rooms_cleared_this_rank, "/6 this rank)")

# Generate all 5 hallways for current rank
func generate_rank_hallways():
	current_rank_hallways.clear()
	current_hallway_index = 0
	
	# Position 0-2: One MUST be treasure (but can be any of first 3)
	var treasure_position = randi_range(0, 2)
	
	for i in range(5):
		var hallway: HallwayDefinition
		
		if i == treasure_position:
			# Force treasure at this position
			hallway = get_treasure_hallway()
		else:
			# Get random hallway valid for this rank and position
			var available = HallwayRegistry.get_available_hallways_for_position(current_rank, i)
			
			# Filter out treasure (already guaranteed one)
			#available = available.filter(func(h): return h.hallway_type != Enums.HallwayType.TREASURE)
			
			if available.size() > 0:
				hallway = pick_weighted_hallway(available)
			else:
				push_error("No hallways available for rank %d position %d" % [current_rank, i])
				continue
		
		current_rank_hallways.append(hallway)
	
	print("Generated hallways for rank %d: %s" % [current_rank, current_rank_hallways.map(func(h): return h.hallway_name)])
	minimap_update_requested.emit()

func get_treasure_hallway() -> HallwayDefinition:
	var treasure_hallways = HallwayRegistry.get_available_hallways_for_rank(current_rank).filter(
		func(h): return h.hallway_type == Enums.HallwayType.TREASURE
	)
	
	if treasure_hallways.size() > 0:
		return treasure_hallways.pick_random()
	else:
		push_error("No treasure hallways found for rank " + str(current_rank))
		return null

func pick_weighted_hallway(available_hallways: Array[HallwayDefinition]) -> HallwayDefinition:
	var weighted_options: Array[HallwayDefinition] = []
	
	for hallway in available_hallways:
		var weight = hallway.spawn_weight
		for i in weight:
			weighted_options.append(hallway)
	
	return weighted_options.pick_random()

# Get current hallway
func get_current_hallway() -> HallwayDefinition:
	if current_hallway_index < current_rank_hallways.size():
		return current_rank_hallways[current_hallway_index]
	return null

# Complete hallway and prepare for room
func complete_hallway():
	awaiting_hallway = false

	# Store the hallway we just completed
	if current_hallway_index < current_rank_hallways.size():
		var completed_hallway = current_rank_hallways[current_hallway_index]
		all_visited_hallways.append(completed_hallway)
		current_rank_visited_hallways.append(completed_hallway)
	
	current_hallway_index += 1
	minimap_update_requested.emit()

	print("Completed hallway %d/5" % current_hallway_index)

func slide_in_menus():
	show_minimap.emit()

func advance_rank():
	current_rank += 1
	current_room_index = 1
	rooms_cleared_this_rank = 0
	current_rank_rooms.clear()
	
	# Generate new hallways for new rank
	generate_rank_hallways()

	minimap_update_requested.emit()
	print("Advanced to Rank ", current_rank)