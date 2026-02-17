class_name DungeonRoomGenerator
extends RefCounted

## Handles all dungeon room generation logic
## Extracted from DungeonManager for modularity
## Updated: Removed campfire room placement (moved to town)

var dungeon_manager: Node  # Reference back to DungeonManager

const ROOMS_PER_RANK = 10

# Rarity distribution by rank
const RARITY_WEIGHTS_BY_RANK = {
	1: {Enums.Rarity.COMMON: 70, Enums.Rarity.RARE: 25, Enums.Rarity.LEGENDARY: 5},
	2: {Enums.Rarity.COMMON: 60, Enums.Rarity.RARE: 30, Enums.Rarity.LEGENDARY: 10},
	3: {Enums.Rarity.COMMON: 50, Enums.Rarity.RARE: 35, Enums.Rarity.LEGENDARY: 15},
	4: {Enums.Rarity.COMMON: 40, Enums.Rarity.RARE: 40, Enums.Rarity.LEGENDARY: 20},
	5: {Enums.Rarity.COMMON: 30, Enums.Rarity.RARE: 45, Enums.Rarity.LEGENDARY: 25}
}

# Utility subtype tracking (for "max 1 of each COMMON utility type")
var used_utility_subtypes: Dictionary = {}

# ============================================================================
# MAIN GENERATION FUNCTION
# ============================================================================

func generate_rank_rooms(current_rank: int) -> Array[RoomData]:
	"""Generate 10 rooms for the given rank with guaranteed distributions"""
	var rooms: Array[RoomData] = []
	rooms.resize(ROOMS_PER_RANK)
	
	# Initialize all slots to null
	for i in range(ROOMS_PER_RANK):
		rooms[i] = null
	
	# Reset utility tracking
	used_utility_subtypes.clear()
	
	# Get available rooms for this rank
	var available_rooms = RoomRegistry.get_available_rooms_for_rank(current_rank)
	if available_rooms.is_empty():
		push_error("[DungeonRoomGenerator] No rooms available for rank %d" % current_rank)
		return rooms
	
	# Place guaranteed rooms (campfire removed - handled by town)
	_place_guaranteed_treasure(rooms, available_rooms, current_rank)
	_place_guaranteed_merchant(rooms, available_rooms, current_rank)
	
	if current_rank >= 2:
		_place_guaranteed_utility(rooms, available_rooms, current_rank)
	
	if current_rank >= 4:
		_place_guaranteed_merchant(rooms, available_rooms, current_rank)  # 2nd merchant
	
	# Fill remaining empty slots with weighted random rooms
	_fill_remaining_slots(rooms, available_rooms, current_rank)
	
	# Assign combat to all rooms
	for room_data in rooms:
		if room_data:
			_assign_combat_to_room(room_data)
	
	# Verify no null rooms remain
	var null_count = 0
	for room_data in rooms:
		if room_data == null:
			null_count += 1
	
	if null_count > 0:
		push_error("[DungeonRoomGenerator] Generated rooms has %d null slots!" % null_count)
	
	print("[DungeonRoomGenerator] Generated %d rooms for rank %d" % [ROOMS_PER_RANK, current_rank])
	return rooms

# ============================================================================
# GUARANTEED ROOM PLACEMENT
# ============================================================================

func _place_guaranteed_treasure(rooms: Array[RoomData], available_rooms: Array[RoomDefinition], rank: int):
	"""Place guaranteed treasure room in positions 1-3"""
	var treasure_rooms = RoomRegistry.get_rooms_by_type_rarity_and_rank(
		Enums.RoomType.TREASURE,
		Enums.Rarity.RARE,
		rank
	)
	
	if treasure_rooms.is_empty():
		print("[DungeonRoomGenerator] No RARE treasure rooms for rank %d" % rank)
		return
	
	var slot = _find_open_slot(rooms, 0, 2)  # Positions 1-3 (indices 0-2)
	if slot >= 0:
		rooms[slot] = _create_room_data(treasure_rooms.pick_random())
		print("[DungeonRoomGenerator] Placed guaranteed RARE treasure at position %d" % (slot + 1))

func _place_guaranteed_merchant(rooms: Array[RoomData], available_rooms: Array[RoomDefinition], rank: int):
	"""Place guaranteed merchant room"""
	var merchant_rooms = RoomRegistry.get_rooms_by_type_rarity_and_rank(
		Enums.RoomType.MERCHANT,
		Enums.Rarity.RARE,
		rank
	)
	
	if merchant_rooms.is_empty():
		print("[DungeonRoomGenerator] No RARE merchant rooms for rank %d" % rank)
		return
	
	var slot = _find_open_slot(rooms, 0, ROOMS_PER_RANK - 1)
	if slot >= 0:
		rooms[slot] = _create_room_data(merchant_rooms.pick_random())
		print("[DungeonRoomGenerator] Placed guaranteed RARE merchant at position %d" % (slot + 1))

func _place_guaranteed_utility(rooms: Array[RoomData], available_rooms: Array[RoomDefinition], rank: int):
	"""Place guaranteed utility room (rank 2+)"""
	var utility_rooms = RoomRegistry.get_rooms_by_type(Enums.RoomType.UTILITY)
	
	if utility_rooms.is_empty():
		print("[DungeonRoomGenerator] No utility rooms available")
		return
	
	var slot = _find_open_slot(rooms, 0, ROOMS_PER_RANK - 1)
	if slot >= 0:
		rooms[slot] = _create_room_data(utility_rooms.pick_random())
		print("[DungeonRoomGenerator] Placed guaranteed utility at position %d" % (slot + 1))

# ============================================================================
# FILL REMAINING SLOTS
# ============================================================================

func _fill_remaining_slots(rooms: Array[RoomData], available_rooms: Array[RoomDefinition], rank: int):
	"""Fill null slots with weighted random rooms, respecting all rules"""
	var rarity_weights = _get_rarity_weights_for_rank(rank)
	
	for i in range(ROOMS_PER_RANK):
		if rooms[i] != null:
			continue  # Already filled by guaranteed placement
		
		# Try up to 20 times to find valid room
		var placed = false
		for attempt in range(20):
			var room_def = _pick_weighted_room_with_rarity(available_rooms, rarity_weights)
			
			# Validate against all rules
			if _can_place_room_at_position(rooms, room_def, i):
				rooms[i] = _create_room_data(room_def)
				_register_placed_utility(room_def)
				placed = true
				break
		
		# Fallback if all attempts failed
		if not placed:
			push_warning("[DungeonRoomGenerator] Using fallback room at position %d" % (i + 1))
			rooms[i] = _create_fallback_room()

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

func _can_place_room_at_position(rooms: Array[RoomData], room_def: RoomDefinition, position: int) -> bool:
	"""Master validation - checks all placement rules"""
	# Rule 1: No adjacent utilities
	if not _validate_no_adjacent_utilities(rooms, room_def, position):
		return false
	
	# Rule 2: Max 1 COMMON utility of each subtype
	if not _check_utility_subtype_limit(room_def):
		return false
	
	return true

func _validate_no_adjacent_utilities(rooms: Array[RoomData], room_def: RoomDefinition, position: int) -> bool:
	"""No two utility rooms next to each other"""
	if room_def.room_type != Enums.RoomType.UTILITY:
		return true
	
	# Check left neighbor
	if position > 0 and rooms[position - 1] != null:
		if rooms[position - 1].room_definition.room_type == Enums.RoomType.UTILITY:
			return false
	
	# Check right neighbor
	if position < ROOMS_PER_RANK - 1 and rooms[position + 1] != null:
		if rooms[position + 1].room_definition.room_type == Enums.RoomType.UTILITY:
			return false
	
	return true

func _check_utility_subtype_limit(room_def: RoomDefinition) -> bool:
	"""Max 1 COMMON utility of each subtype"""
	if room_def.room_type != Enums.RoomType.UTILITY:
		return true
	if room_def.rarity != Enums.Rarity.COMMON:
		return true
	
	var subtype = room_def.utility_subtype
	if subtype.is_empty():
		return true
	
	return not used_utility_subtypes.has(subtype)

func _register_placed_utility(room_def: RoomDefinition):
	"""Track utility subtypes"""
	if room_def.room_type == Enums.RoomType.UTILITY:
		if room_def.rarity == Enums.Rarity.COMMON:
			var subtype = room_def.utility_subtype
			if not subtype.is_empty():
				used_utility_subtypes[subtype] = 1

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _find_open_slot(rooms: Array[RoomData], start_idx: int, end_idx: int) -> int:
	"""Find random open slot in range, returns -1 if none found"""
	var open_slots: Array[int] = []
	
	for i in range(start_idx, end_idx + 1):
		if i < rooms.size() and rooms[i] == null:
			open_slots.append(i)
	
	if open_slots.size() == 0:
		return -1
	
	return open_slots.pick_random()

func _create_room_data(room_def: RoomDefinition) -> RoomData:
	"""Create RoomData instance from RoomDefinition"""
	var room_data = RoomData.new()
	room_data.room_definition = room_def
	room_data.chosen_event_scene = room_def.get_random_event()
	return room_data

func _assign_combat_to_room(room_data: RoomData):
	"""Roll for combat encounter based on room definition's combat chance"""
	if not room_data or not room_data.room_definition:
		return
	
	var room_def = room_data.room_definition
	
	# Specific enemy always overrides
	if room_def.specific_enemy:
		room_data.assigned_enemy = room_def.specific_enemy
		room_data.has_combat_this_instance = true
		return
	
	# Roll for random combat
	if room_def.can_have_random_combat and room_def.random_enemy_pool.size() > 0:
		var roll = randf()
		if roll < room_def.random_combat_chance:
			room_data.assigned_enemy = room_def.random_enemy_pool.pick_random()
			room_data.has_combat_this_instance = true
		else:
			room_data.has_combat_this_instance = false
	else:
		room_data.has_combat_this_instance = false

func _pick_weighted_room_with_rarity(available_rooms: Array[RoomDefinition], rarity_weights: Dictionary) -> RoomDefinition:
	"""Pick room using spawn_weight AND rarity weight"""
	var weighted_pool: Array[RoomDefinition] = []
	
	for room_def in available_rooms:
		var rarity_weight = rarity_weights.get(room_def.rarity, 10)
		var room_weight = room_def.spawn_weight
		var total_weight = (rarity_weight * room_weight) / 10
		
		for i in range(total_weight):
			weighted_pool.append(room_def)
	
	if weighted_pool.is_empty():
		return available_rooms.pick_random()
	
	return weighted_pool.pick_random()

func _get_rarity_weights_for_rank(rank: int) -> Dictionary:
	"""Get rarity distribution for current rank"""
	if RARITY_WEIGHTS_BY_RANK.has(rank):
		return RARITY_WEIGHTS_BY_RANK[rank]
	
	# Default for ranks beyond 5
	return {
		Enums.Rarity.COMMON: 50,
		Enums.Rarity.RARE: 40,
		Enums.Rarity.LEGENDARY: 10
	}

func _create_fallback_room() -> RoomData:
	"""Create a basic fallback treasure room if generation fails"""
	var fallback_rooms = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.TREASURE,
		Enums.Rarity.COMMON
	)
	
	if fallback_rooms.is_empty():
		var starter = RoomRegistry.get_room_definition("starter")
		if starter:
			return _create_room_data(starter)
		
		# Ultimate fallback
		push_error("[DungeonRoomGenerator] No fallback rooms available!")
		return RoomData.new()
	
	return _create_room_data(fallback_rooms.pick_random())