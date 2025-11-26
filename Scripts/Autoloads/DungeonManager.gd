extends Node

signal show_minimap()
signal room_transition_requested(room_data: RoomData)
signal minimap_update_requested()


# ============ ADVANCED DISTRIBUTION RULES ============

const SHORTCUT_SKIP_RANGES: Dictionary = {
	Enums.Rarity.UNCOMMON: {"min": 1, "max": 2},       # UNCOMMON: skip 1-2 rooms
	Enums.Rarity.RARE: {"min": 2, "max": 3},       # RARE: skip 2-3 rooms	
	Enums.Rarity.LEGENDARY: {"min": 3, "max": 6}   # LEGENDARY: skip 3-6
}

# Adjacency rules
const ADJACENCY_RULES: Dictionary = {
	Enums.RoomType.CAMPFIRE: {
		"cannot_be_adjacent_to": [Enums.RoomType.CAMPFIRE],
		"min_spacing": 3  # At least 1 room between campfires
	},
	Enums.RoomType.UTILITY: {
		"cannot_be_adjacent_to": [Enums.RoomType.UTILITY],
		"min_spacing": 1  # At least 1 room between utilities
	}
}

# Type count limits
const TYPE_COUNT_LIMITS: Dictionary = {
	Enums.RoomType.UTILITY: {
		Enums.Rarity.COMMON: 2,    # Max 2 COMMON utilities
		Enums.Rarity.RARE: 3,      # Max 3 RARE utilities
		Enums.Rarity.LEGENDARY: 1  # Max 1 LEGENDARY utility
	},
	Enums.RoomType.CAMPFIRE: {
		Enums.Rarity.COMMON: 2,
		Enums.Rarity.RARE: 0,
		Enums.Rarity.LEGENDARY: 0  # No legendary campfires
	}
}

# Specific room limits (unique rooms)
const SPECIFIC_ROOM_LIMITS: Dictionary = {
	"A strange altar": 1,
	"another specific room": 1
}

# Dynamic rarity weights by rank
const RARITY_WEIGHTS_BY_RANK: Dictionary = {
	1: {Enums.Rarity.COMMON: 75, Enums.Rarity.RARE: 25, Enums.Rarity.LEGENDARY: 0},
	2: {Enums.Rarity.COMMON: 70, Enums.Rarity.RARE: 30, Enums.Rarity.LEGENDARY: 0},
	3: {Enums.Rarity.COMMON: 60, Enums.Rarity.RARE: 35, Enums.Rarity.LEGENDARY: 5},
	4: {Enums.Rarity.COMMON: 45, Enums.Rarity.RARE: 45, Enums.Rarity.LEGENDARY: 10},
	5: {Enums.Rarity.COMMON: 40, Enums.Rarity.RARE: 45, Enums.Rarity.LEGENDARY: 15}
}

# Utility subtype tracking (for "max 1 of each COMMON utility type")
var used_utility_subtypes: Dictionary = {}


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
	current_rank_rooms[0] = room_data  # first room always starter room

	return room_data

func generate_rank_rooms():
	# Generate 10 predetermined rooms with guaranteed distributions
	current_rank_rooms.clear()
	current_room_index = 0
	used_utility_subtypes.clear()

	# Create empty array with 10 slots
	current_rank_rooms.resize(ROOMS_PER_RANK)
	for i in range(ROOMS_PER_RANK):
		current_rank_rooms[i] = null
	
	# Apply guaranteed room placements
	place_guaranteed_treasure()
	place_guaranteed_merchant()
	place_guaranteed_campfire()
	
	# Rank-specific guarantees
	if current_rank >= 2:
		place_guaranteed_utility()
	
	if current_rank >= 4:
		place_guaranteed_merchant()  # 2nd merchant for ranks 4-5
	
	# Fill remaining empty slots with weighted random rooms
	fill_remaining_slots()
	
	# Assign combat to all rooms
	for room_data in current_rank_rooms:
		if room_data:
			assign_combat_to_room(room_data)
	
	# Verify no null rooms remain
	var null_count = 0
	for room_data in current_rank_rooms:
		if room_data == null:
			null_count += 1
	
	if null_count > 0:
		push_error("generate_rank_rooms() left %d null rooms!" % null_count)
	
	print("[DungeonManager] Generated %d rooms for rank %d" % [current_rank_rooms.size(), current_rank])
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


func check_for_shortcuts(completed_room: RoomData) -> Array[ShortcutOption]:
	"""Called after room complete - should shortcuts appear?"""
	
	var room_def = completed_room.room_definition
	
	# Check 1: Can this room type spawn shortcuts?
	if not room_def.can_spawn_shortcuts:
		return []  # No shortcuts from this room
	
	# Check 2: Roll the dice
	var roll = randf()  # 0.0 to 1.0
	if roll > room_def.shortcut_chance:
		return []  # Didn't roll high enough
	
	print("[Shortcut] Triggered! Generating options...")
	
	# Generate 1-2 shortcut options
	return generate_shortcut_options(room_def.rarity)

func generate_shortcut_options(source_rarity: Enums.Rarity) -> Array[ShortcutOption]:
	"""Generate 1-2 shortcut destinations"""
	
	var options: Array[ShortcutOption] = []
	
	# Get rooms we could shortcut to (same rarity, not on current path)
	var available = get_shortcut_destinations(source_rarity)
	
	if available.is_empty():
		print("[Shortcut] No valid destinations found")
		return []
	
	# How many options to show? (randomly 1 or 2)
	var num_options = 2 if randf() < 0.4 else 1  # 40% chance for 2 options
	num_options = min(num_options, available.size())
	
	# Get skip range for this rarity
	var skip_range = SHORTCUT_SKIP_RANGES.get(source_rarity, {"min": 1, "max": 3})
	
	# Create options
	for i in range(num_options):
		# Pick random destination
		var dest_room = available.pop_at(randi() % available.size())
		
		# Pick random skip count
		var skip_count = randi_range(skip_range["min"], skip_range["max"])
		
		# Will it have combat?
		var has_combat = will_room_have_combat(dest_room)
		
		# Create option
		var option = ShortcutOption.new(dest_room, skip_count, has_combat)
		options.append(option)
	
	return options

func get_shortcut_destinations(source_rarity: Enums.Rarity) -> Array[RoomDefinition]:
	"""Get rooms that can be shortcut targets (same rarity, not on current path)"""
	
	var all_available: Array[RoomDefinition] = []
	
	# Get all rooms of this rarity for current rank
	for room_def in RoomRegistry.get_available_rooms_for_rank(current_rank):
		if room_def.rarity == source_rarity:
			all_available.append(room_def)
	
	# Filter out rooms already on our current path
	var current_room_defs: Array[RoomDefinition] = []
	for room_data in current_rank_rooms:
		if room_data:
			current_room_defs.append(room_data.room_definition)
	
	# Return only rooms NOT on path
	var destinations: Array[RoomDefinition] = []
	for room_def in all_available:
		if room_def not in current_room_defs:
			destinations.append(room_def)
	
	return destinations

func will_room_have_combat(room_def: RoomDefinition) -> bool:
	"""Pre-roll combat for UI preview"""
	
	if room_def.specific_enemy:
		return true  # Always has combat
	
	if room_def.can_have_random_combat and room_def.random_enemy_pool.size() > 0:
		return randf() < room_def.random_combat_chance
	
	return false

func apply_shortcut(option: ShortcutOption):
	"""Player chose a shortcut - modify the rank rooms"""
	
	print("[Shortcut] Applying: %s (skip %d)" % [option.display_name, option.skip_count])
	
	# Mark skipped rooms with special flag
	for i in range(option.skip_count):
		var skip_index = current_room_index + 1 + i
		if skip_index < current_rank_rooms.size():
			mark_room_skipped(skip_index)
	
	# Replace destination room
	var dest_index = option.get_destination_index(current_room_index)
	if dest_index < current_rank_rooms.size():
		# Create new room data
		var new_room = create_room_data(option.destination_room)
		new_room.has_combat_this_instance = option.has_combat
		
		if option.has_combat and option.destination_room.random_enemy_pool.size() > 0:
			new_room.assigned_enemy = option.destination_room.random_enemy_pool.pick_random()
		
		# Replace the room slot
		current_rank_rooms[dest_index] = new_room
	
	# Update minimap
	minimap_update_requested.emit()

func mark_room_skipped(room_index: int):
	"""Add skip flag to room (for minimap ❌ icon)"""
	if room_index >= 0 and room_index < current_rank_rooms.size():
		var room = current_rank_rooms[room_index]
		if room:
			room.room_state["skipped"] = true


# ============================================================================
# GUARANTEED PLACEMENT HELPERS
# ============================================================================

func place_guaranteed_treasure():
	"""Place 1 RARE treasure in positions 1-3 (indices 0-2)"""
	var treasure_defs = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.TREASURE,
		Enums.Rarity.UNCOMMON
	)
	
	if treasure_defs.size() == 0:
		push_warning("[DungeonManager] No RARE treasure rooms available for guaranteed placement")
		return
	
	# Find open slot in range 0-2
	var position = find_open_slot_in_range(0, 2)
	if position == -1:
		push_warning("[DungeonManager] No open slots in positions 1-3 for treasure")
		return
	
	var room_def = treasure_defs.pick_random()
	current_rank_rooms[position] = create_room_data(room_def)
	print("[DungeonManager] Placed RARE treasure at position %d" % (position + 1))

func place_guaranteed_merchant():
	"""Place 1 RARE merchant in any open position"""
	var merchant_defs = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.MERCHANT,
		Enums.Rarity.UNCOMMON
	)
	
	if merchant_defs.size() == 0:
		push_warning("[DungeonManager] No RARE merchant rooms available for guaranteed placement")
		return
	
	# Find any open slot
	var position = find_open_slot_in_range(0, ROOMS_PER_RANK - 1)
	if position == -1:
		push_warning("[DungeonManager] No open slots for merchant")
		return
	
	var room_def = merchant_defs.pick_random()
	current_rank_rooms[position] = create_room_data(room_def)
	print("[DungeonManager] Placed RARE merchant at position %d" % (position + 1))

func place_guaranteed_campfire():
	"""Place 1 RARE campfire in positions 9-10 (indices 8-9)"""
	var campfire_defs = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.CAMPFIRE,
		Enums.Rarity.COMMON
	)
	
	if campfire_defs.size() == 0:
		push_warning("[DungeonManager] No RARE campfire rooms available for guaranteed placement")
		return
	
	# Find open slot in range 8-9
	var position = find_open_slot_in_range(8, 9)
	if position == -1:
		push_warning("[DungeonManager] No open slots in positions 9-10 for campfire")
		return
	
	var room_def = campfire_defs.pick_random()
	current_rank_rooms[position] = create_room_data(room_def)
	print("[DungeonManager] Placed RARE campfire at position %d" % (position + 1))

func place_guaranteed_utility():
	"""Place 1 RARE utility room in any open position (ranks 2+)"""
	var utility_defs = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.UTILITY,
		Enums.Rarity.UNCOMMON
	)
	
	if utility_defs.size() == 0:
		push_warning("[DungeonManager] No RARE utility rooms available for guaranteed placement")
		return
	
	# Find any open slot
	var position = find_open_slot_in_range(0, ROOMS_PER_RANK - 1)
	if position == -1:
		push_warning("[DungeonManager] No open slots for utility room")
		return
	
	var room_def = utility_defs.pick_random()
	current_rank_rooms[position] = create_room_data(room_def)
	print("[DungeonManager] Placed RARE utility at position %d" % (position + 1))

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func find_open_slot_in_range(start_idx: int, end_idx: int) -> int:
	"""Find first null slot in given range. Returns -1 if none found."""
	var open_slots: Array[int] = []
	
	for i in range(start_idx, end_idx + 1):
		if i < current_rank_rooms.size() and current_rank_rooms[i] == null:
			open_slots.append(i)
	
	if open_slots.size() == 0:
		return -1
	
	# Pick random slot from available options
	return open_slots.pick_random()

func create_room_data(room_def: RoomDefinition) -> RoomData:
	"""Create RoomData instance from RoomDefinition"""
	var room_data = RoomData.new()
	room_data.room_definition = room_def
	room_data.chosen_event_scene = room_def.get_random_event()
	return room_data

func fill_remaining_slots():
	"""Fill null slots with weighted random rooms, respecting all rules"""
	var available_rooms = RoomRegistry.get_available_rooms_for_rank(current_rank)
	var rarity_weights = get_rarity_weights_for_rank(current_rank)
	
	if available_rooms.is_empty():
		push_error("[DungeonManager] No rooms available for rank %d" % current_rank)
		return
	
	for i in range(ROOMS_PER_RANK):
		if current_rank_rooms[i] != null:
			continue  # Already filled by guaranteed placement
		
		# Try up to 20 times to find valid room
		var placed = false
		for attempt in range(20):
			var room_def = pick_weighted_room_definition_with_rarity(
				available_rooms,
				rarity_weights
			)
			
			# Validate against all rules
			if can_place_room_at_position(room_def, i):
				current_rank_rooms[i] = create_room_data(room_def)
				register_placed_utility(room_def)
				placed = true
				break
		
		# Fallback if all attempts failed
		if not placed:
			push_warning("[DungeonManager] Using fallback room at position %d" % i)
			current_rank_rooms[i] = create_fallback_room(i)

# ============================================================================
# VALIDATION RULE FUNCS
# ============================================================================

func can_place_room_at_position(room_def: RoomDefinition, position: int) -> bool:
	"""Master validation - checks all rules"""
	if not check_adjacency_rules(room_def, position):
		return false
	if not check_type_count_limits(room_def):
		return false
	if not check_specific_room_limits(room_def):
		return false
	if not check_utility_subtype_limit(room_def):
		return false
	return true

func check_adjacency_rules(room_def: RoomDefinition, position: int) -> bool:
	"""Check spacing between room types"""
	if not ADJACENCY_RULES.has(room_def.room_type):
		return true
	
	var rule = ADJACENCY_RULES[room_def.room_type]
	var forbidden_types = rule.get("cannot_be_adjacent_to", [])
	var min_spacing = rule.get("min_spacing", 0)
	
	for offset in range(1, min_spacing + 2):
		# Check left
		var left_idx = position - offset
		if left_idx >= 0 and current_rank_rooms[left_idx] != null:
			if current_rank_rooms[left_idx].room_definition.room_type in forbidden_types:
				return false
		
		# Check right
		var right_idx = position + offset
		if right_idx < ROOMS_PER_RANK and current_rank_rooms[right_idx] != null:
			if current_rank_rooms[right_idx].room_definition.room_type in forbidden_types:
				return false
	
	return true

func check_type_count_limits(room_def: RoomDefinition) -> bool:
	"""Check type+rarity limits"""
	if TYPE_COUNT_LIMITS.has(room_def.room_type):
		var type_limits = TYPE_COUNT_LIMITS[room_def.room_type]
		if type_limits.has(room_def.rarity):
			var max_count = type_limits[room_def.rarity]
			var current_count = count_rooms_by_type_and_rarity(
				room_def.room_type,
				room_def.rarity
			)
			if current_count >= max_count:
				return false
	return true

func check_specific_room_limits(room_def: RoomDefinition) -> bool:
	"""Check unique room limits"""
	if SPECIFIC_ROOM_LIMITS.has(room_def.room_name):
		var max_count = SPECIFIC_ROOM_LIMITS[room_def.room_name]
		var current_count = count_rooms_by_name(room_def.room_name)
		if current_count >= max_count:
			return false
	return true

func check_utility_subtype_limit(room_def: RoomDefinition) -> bool:
	"""Max 1 COMMON utility of each subtype"""
	if room_def.room_type != Enums.RoomType.UTILITY:
		return true
	if room_def.rarity != Enums.Rarity.COMMON:
		return true
	
	var subtype = room_def.utility_subtype
	if subtype.is_empty():
		return true
	
	return not used_utility_subtypes.has(subtype)

func count_rooms_by_type_and_rarity(type: Enums.RoomType, rarity: Enums.Rarity) -> int:
	var count = 0
	for room in current_rank_rooms:
		if room and room.room_definition.room_type == type and room.room_definition.rarity == rarity:
			count += 1
	return count

func count_rooms_by_name(room_name: String) -> int:
	var count = 0
	for room in current_rank_rooms:
		if room and room.room_definition.room_name == room_name:
			count += 1
	return count

func register_placed_utility(room_def: RoomDefinition):
	"""Track utility subtypes"""
	if room_def.room_type == Enums.RoomType.UTILITY:
		if room_def.rarity == Enums.Rarity.COMMON:
			var subtype = room_def.utility_subtype
			if not subtype.is_empty():
				used_utility_subtypes[subtype] = 1

func create_fallback_room(position: int) -> RoomData:
	"""Safe fallback that won't violate rules"""
	var fallbacks = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.TREASURE,
		Enums.Rarity.COMMON
	)
	
	if fallbacks.is_empty():
		var starter = RoomRegistry.get_room_definition("starter")
		return create_room_data(starter)
	
	return create_room_data(fallbacks.pick_random())

func get_rarity_weights_for_rank(rank: int) -> Dictionary:
	"""Get rarity distribution for current rank"""
	if RARITY_WEIGHTS_BY_RANK.has(rank):
		return RARITY_WEIGHTS_BY_RANK[rank]
	
	# Default for ranks beyond 5
	return {
		Enums.Rarity.COMMON: 50,
		Enums.Rarity.RARE: 40,
		Enums.Rarity.LEGENDARY: 10
	}

func pick_weighted_room_definition_with_rarity(
	available_rooms: Array[RoomDefinition],
	rarity_weights: Dictionary
) -> RoomDefinition:
	"""Pick room using spawn_weight AND rarity weight"""
	var rarity_pool: Array[RoomDefinition] = []
	
	for room_def in available_rooms:
		var rarity_weight = rarity_weights.get(room_def.rarity, 10)
		var room_weight = room_def.spawn_weight
		var total_weight = (rarity_weight * room_weight) / 10
		
		for i in range(total_weight):
			rarity_pool.append(room_def)
	
	if rarity_pool.is_empty():
		return available_rooms.pick_random()
	
	return rarity_pool.pick_random()

# ============================================================================
# DEBUG COMMANDS
# ============================================================================

func debug_print_rank():
	"""Print detailed rank layout"""
	print("\n=== RANK %d LAYOUT ===" % current_rank)
	for i in current_rank_rooms.size():
		var room = current_rank_rooms[i]
		if room:
			var combat_icon = "⚔️" if room.has_combat_this_instance else "  "
			var rarity_str = Enums.Rarity.keys()[room.room_definition.rarity]
			print("  [%d] %s %s %s (%s)" % [
				i + 1,
				combat_icon,
				room.room_definition.room_name,
				room.room_definition.room_type,
				rarity_str
			])
		else:
			print("  [%d] NULL ROOM" % (i + 1))
	print("===================\n")

func debug_skip_to_boss():
	"""Jump directly to boss fight"""
	rooms_cleared_this_rank = ROOMS_PER_RANK
	current_room_index = ROOMS_PER_RANK - 1
	minimap_update_requested.emit()

func debug_regenerate_rank():
	"""Regenerate current rank rooms"""
	generate_rank_rooms()

func debug_force_combat_all():
	"""Set all rooms to 100% combat"""
	for room in current_rank_rooms:
		if room:
			room.has_combat_this_instance = true
	minimap_update_requested.emit()

func debug_clear_combat_all():
	"""Remove combat from all rooms"""
	for room in current_rank_rooms:
		if room:
			room.has_combat_this_instance = false
	minimap_update_requested.emit()
