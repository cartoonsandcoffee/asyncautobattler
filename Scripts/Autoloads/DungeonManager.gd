extends Node

signal show_minimap()
signal room_transition_requested(room_data: RoomData)
signal minimap_update_requested()

const ROOMS_PER_RANK = 10
const BOSS_ROOM_INDEX = 10  # Boss is last room

var current_rank: int = 1
var current_room_index: int = 0  # 0-10 (0 = start, 10 = last room before boss)
var rooms_cleared_this_rank: int = 0

var all_visited_rooms: Array[RoomData] = []
var current_rank_rooms: Array[RoomData] = []  # Predetermined rooms for this rank

var pending_room_data: RoomData = null  # For future hallway→room transition (not used yet)

func generate_starter_room() -> RoomData:
	var starter_def = RoomRegistry.get_room_definition("starter")
	if starter_def == null:
		push_error("Starter room definition not found!")
		return null
	
	var room_data = RoomData.new()
	room_data.room_definition = starter_def
	room_data.chosen_event_scene = starter_def.get_random_event()
	
	# Generate the rooms for rank 1
	generate_rank_rooms()
	
	return room_data

func generate_rank_rooms():
	# Generate all predetermined rooms for the current rank
	current_rank_rooms.clear()
	current_room_index = 0
	
	# Get available room definitions for current rank
	var available_rooms = RoomRegistry.get_available_rooms_for_rank(current_rank)
	
	if available_rooms.size() == 0:
		push_error("No rooms available for rank " + str(current_rank))
		return
	
	# Generate rooms
	for i in range(ROOMS_PER_RANK):
		var room_def = pick_weighted_room_definition(available_rooms)
		var event_scene = room_def.get_random_event()
		
		var room_data = RoomData.new()
		room_data.room_definition = room_def
		room_data.chosen_event_scene = event_scene
		
		# Assign combat for this specific room instance
		assign_combat_to_room(room_data)
		
		current_rank_rooms.append(room_data)
	
	print("Generated %d rooms for rank %d" % [current_rank_rooms.size(), current_rank])
	minimap_update_requested.emit()

func assign_combat_to_room(room_data: RoomData):
	# Determine if this room instance will have combat
	var room_def = room_data.room_definition
	
	# Specific enemy always overrides
	if room_def.specific_enemy:
		room_data.assigned_enemy = room_def.specific_enemy
		room_data.has_combat_this_instance = true
		return
	
	# Check random combat roll
	if room_def.can_have_random_combat and room_def.random_enemy_pool.size() > 0:
		var roll = randf()
		if roll < room_def.random_combat_chance:
			# Combat triggered - pick random enemy from pool
			var enemy = room_def.random_enemy_pool.pick_random()
			room_data.assigned_enemy = enemy
			room_data.has_combat_this_instance = true
		else:
			# No combat this time
			room_data.has_combat_this_instance = false
	else:
		# Room cannot have combat
		room_data.has_combat_this_instance = false

func pick_weighted_room_definition(available_rooms: Array[RoomDefinition]) -> RoomDefinition:
	# Pick a room definition based on spawn weights
	var weighted_options: Array[RoomDefinition] = []
	
	for room_def in available_rooms:
		var weight = room_def.spawn_weight
		for i in weight:
			weighted_options.append(room_def)
	
	return weighted_options.pick_random()

func get_current_room() -> RoomData:
	"""Get the room player should be entering next"""
	if current_room_index < current_rank_rooms.size():
		return current_rank_rooms[current_room_index]
	return null

# Add method to get boss room data:
func get_boss_room() -> RoomData:
	"""Get boss room for current rank"""
	var boss_def = RoomRegistry.get_room_definition("boss")  # You'll need to create this
	if boss_def:
		var boss_room = RoomData.new()
		boss_room.room_definition = boss_def
		boss_room.chosen_event_scene = boss_def.get_random_event()
		return boss_room
	return null
	
func advance_room():
	# Move to next room in sequence
	current_room_index += 1
	rooms_cleared_this_rank += 1
	
	# Update tracking
	minimap_update_requested.emit()
	
	# Check if rank complete (10 rooms cleared = time for boss)
	if rooms_cleared_this_rank >= ROOMS_PER_RANK:
		print("Rank %d complete! Time for boss." % current_rank)
		# Boss fight would trigger here
	
	print("Advanced to room %d/%d (rank %d)" % [current_room_index + 1, ROOMS_PER_RANK, current_rank])

func advance_rank():
	# Move to next rank
	current_rank += 1
	current_room_index = 0
	rooms_cleared_this_rank = 0
	all_visited_rooms.clear()  # Or keep for history
	
	# Generate new rooms for new rank
	generate_rank_rooms()
	
	minimap_update_requested.emit()
	print("Advanced to Rank %d" % current_rank)

func get_room_type_display_name(room_data: RoomData) -> String:
	if room_data.room_definition:
		return room_data.room_definition.room_name
	else:
		return "Unknown Room"

func get_room_type_icon(room_data: RoomData) -> Texture2D:
	if room_data.room_definition:
		return room_data.room_definition.room_icon
	else:
		return null

func slide_in_menus():
	show_minimap.emit()
