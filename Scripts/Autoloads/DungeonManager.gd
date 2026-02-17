extends Node

## DungeonManager - Simplified Room Currency System
## - Generates rooms on-demand (no pool)
## - Player owns room currency
## - Can load specific room types (dungeon, boss, town)

# ============================================================================
# MODULE
# ============================================================================

var room_generator: DungeonRoomGenerator

# ============================================================================
# STATE TRACKING
# ============================================================================

var current_rank: int = 1
var rooms_visited_this_rank: int = 0  # For stats/tracking

# Room history (optional - for achievements/stats)
var all_visited_rooms: Array[RoomData] = []

# Boss data (fetched from Supabase via existing BossHandler)
var current_boss_data: Dictionary = {}
var current_boss_enemy: Enemy = null

var _initialized: bool = false

# ============================================================================
# SIGNALS
# ============================================================================

signal boss_loaded(boss: Enemy)

# ============================================================================
# TESTING/DEBUG
# ============================================================================

@export var testing_force_next_room: bool = false
@export var testing_room_definition: RoomDefinition

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	pass

func initialize():
	if _initialized:
		return

	_initialized = true

	# Initialize room generator module
	room_generator = DungeonRoomGenerator.new()
	room_generator.dungeon_manager = self
	
	reset()
	print("[DungeonManager] Initialized - on-demand room generation")


func reset():
	current_rank = 5
	rooms_visited_this_rank = 0

	all_visited_rooms.clear()
	current_boss_data = {}
	current_boss_enemy = null	
# ============================================================================
# RANK INITIALIZATION
# ============================================================================

func initialize_rank():
	"""Initialize the current rank - fetch boss and prepare"""
	rooms_visited_this_rank = 0
	if current_rank < 6:
		await _fetch_and_create_boss()
	else:
		await _fetch_champion_opponent()
		
	print("[DungeonManager] Rank %d initialized" % current_rank)

# ============================================================================
# ROOM GENERATION - ON DEMAND
# ============================================================================

func get_random_dungeon_room() -> RoomData:
	"""Generate a random dungeon room based on rank and weights"""
	
	# TESTING: Override with test room if enabled
	if testing_force_next_room and testing_room_definition:
		var debug_room = RoomData.new()
		debug_room.room_definition = testing_room_definition
		debug_room.chosen_event_scene = testing_room_definition.get_random_event()
		room_generator._assign_combat_to_room(debug_room)
		print("[DungeonManager] TEST: Forced room: %s" % testing_room_definition.room_name)
		testing_force_next_room = false  # Only once
		return debug_room
	
	# Get available rooms for current rank
	var available_rooms = RoomRegistry.get_available_rooms_for_rank(current_rank)
	if available_rooms.is_empty():
		push_error("[DungeonManager] No rooms available for rank %d!" % current_rank)
		return _get_fallback_room()
	
	# Get rarity weights for this rank
	var rarity_weights = room_generator._get_rarity_weights_for_rank(current_rank)
	
	# Pick weighted random room
	var room_def = room_generator._pick_weighted_room_with_rarity(available_rooms, rarity_weights)
	
	# Create room data
	var room_data = room_generator._create_room_data(room_def)
	
	# Assign combat
	room_generator._assign_combat_to_room(room_data)
	
	print("[DungeonManager] Generated random room: %s (Rank %d)" % [room_def.room_name, current_rank])
	return room_data

func get_boss_room() -> RoomData:
	"""Get the boss room for current rank"""
	var boss_def = RoomRegistry.get_room_definition("boss")
	
	if not boss_def:
		push_error("[DungeonManager] No boss room definition found!")
		return null
	
	var boss_room = RoomData.new()
	boss_room.room_definition = boss_def
	boss_room.chosen_event_scene = boss_def.get_random_event()
	boss_room.has_combat_this_instance = true
	boss_room.assigned_enemy = current_boss_enemy
	
	print("[DungeonManager] Loading boss room for rank %d" % current_rank)
	return boss_room

func get_town_room() -> RoomData:
	"""Get the town 'room' - for loading town scene"""
	# Town will be handled differently (likely a dedicated scene)
	# This is a placeholder for consistency
	var town_def = RoomRegistry.get_room_definition("town")
	
	if not town_def:
		print("[DungeonManager] No town room definition - town handled separately")
		return null
	
	var town_room = RoomData.new()
	town_room.room_definition = town_def
	town_room.chosen_event_scene = town_def.get_random_event()
	
	print("[DungeonManager] Loading town")
	return town_room

func get_starter_room() -> RoomData:
	"""Get the starter room for a new game"""
	var starter_def = RoomRegistry.get_room_definition("starter")
	
	if not starter_def:
		push_error("[DungeonManager] No starter room found!")
		return null
	
	var room_data = RoomData.new()
	room_data.room_definition = starter_def
	room_data.chosen_event_scene = starter_def.get_random_event()
	
	print("[DungeonManager] Loading starter room")
	return room_data

func _get_fallback_room() -> RoomData:
	"""Create a basic fallback room if generation fails"""
	var fallback_rooms = RoomRegistry.get_rooms_by_type_and_rarity(
		Enums.RoomType.TREASURE,
		Enums.Rarity.COMMON
	)
	
	if not fallback_rooms.is_empty():
		return room_generator._create_room_data(fallback_rooms.pick_random())
	
	# Ultimate fallback
	push_error("[DungeonManager] No fallback rooms available!")
	return RoomData.new()

# ============================================================================
# ROOM COMPLETION
# ============================================================================

func complete_room(room_data: RoomData):
	"""Called when player completes a room - track stats and consume currency"""
	rooms_visited_this_rank += 1
	all_visited_rooms.append(room_data)
	
	print("[DungeonManager] Room completed: %s. Total this rank: %d, Player rooms: %d" % [
		room_data.room_definition.room_name if room_data else "Unknown",
		rooms_visited_this_rank,
		Player.rooms_left_this_rank
	])

# ============================================================================
# BOSS HANDLING
# ============================================================================

func _fetch_and_create_boss():
	"""Fetch opponent from Supabase and create boss enemy for this rank"""
	print("[DungeonManager] Fetching boss for rank %d..." % current_rank)
	
	# Check if SupabaseManager exists
	if not has_node("/root/SupabaseManager"):
		push_warning("[DungeonManager] SupabaseManager not found, using fallback boss")
		current_boss_enemy = BossHandler.get_fallback_boss(current_rank)
		boss_loaded.emit(current_boss_enemy)
		return
	
	# Fetch opponent data
	var player_id = Player.load_or_generate_uuid()
	current_boss_data = await SupabaseManager.fetch_opponent_for_rank(current_rank, player_id)
	
	# Create boss enemy using existing BossHandler autoload
	if current_boss_data.is_empty():
		print("[DungeonManager] No opponents found, using fallback boss")
		current_boss_enemy = BossHandler.get_fallback_boss(current_rank)
	else:
		print("[DungeonManager] Boss data fetched: %s" % current_boss_data.get("username", "Unknown"))
		current_boss_enemy = BossHandler.create_boss_enemy(current_boss_data)
	
	if not current_boss_enemy:
		push_error("[DungeonManager] Boss creation failed!")
		return
	
	print("[DungeonManager] Boss ready: %s (HP: %d)" % [
		current_boss_enemy.enemy_name,
		current_boss_enemy.stats.hit_points
	])
	
	boss_loaded.emit(current_boss_enemy)

func _fetch_champion_opponent():
	"""Fetch a champion from the active_champions table."""
	print("[DungeonManager] Fetching champion opponent...")
	
	if not has_node("/root/SupabaseManager"):
		push_warning("[DungeonManager] SupabaseManager not found, using fallback boss")
		current_boss_enemy = BossHandler.get_fallback_boss(6)
		boss_loaded.emit(current_boss_enemy)
		return
	
	# Fetch champion opponent (excluding player's own champions)
	var player_id = Player.load_or_generate_uuid()
	current_boss_data = await SupabaseManager.fetch_champion_opponent(player_id)
	
	# Create boss enemy
	if current_boss_data.is_empty():
		print("[DungeonManager] No champions found, using fallback boss")
		current_boss_enemy = BossHandler.get_fallback_boss(6)
	else:
		print("[DungeonManager] Champion fetched: %s (Victories: %d)" % [
			current_boss_data.get("username", "Unknown"),
			current_boss_data.get("champion_victories", 0)
		])

		current_boss_enemy = BossHandler.create_boss_enemy(current_boss_data)

		if current_boss_data.get("is_shadow", false):
			print("Fighting a shadow of %s" % current_boss_data.username)
			current_boss_enemy.enemy_name += " (Shadow)"
			

	if not current_boss_enemy:
		push_error("[DungeonManager] Champion creation failed! Boss will be null.")
		return
	
	print("[DungeonManager] Champion ready: %s (HP: %d, Items: %d)" % [
		current_boss_enemy.enemy_name,
		current_boss_enemy.stats.hit_points,
		current_boss_enemy.inventory.get_item_count()
	])
	
	# Emit signal for map zoom panel to update
	boss_loaded.emit(current_boss_enemy)

# ============================================================================
# RANK PROGRESSION
# ============================================================================

func advance_rank():
	"""Advance to next rank after boss victory"""
	current_rank += 1

	rooms_visited_this_rank = 0
	
	# Increase inventory size: +2 slots per rank (4,6,8,10,12)
	var current_size = Player.inventory.max_item_slots
	if current_size < 12:
		Player.inventory.set_inventory_size(current_size + 2)
		print("[DungeonManager] Rank %d! Inventory expanded to %d slots" % [
			current_rank, 
			Player.inventory.max_item_slots
		])
	
	# Clear old boss data
	current_boss_data = {}
	current_boss_enemy = null
	
	# Initialize new rank
	await initialize_rank()
	
	print("[DungeonManager] Advanced to rank %d" % current_rank)

func is_champion_rank() -> bool:
	"""Returns true if player is in rank 6 (champion rank)."""
	return current_rank == 6

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func can_enter_dungeon() -> bool:
	"""Check if player has rooms remaining to enter dungeon"""
	return Player.has_rooms_remaining()

func get_room_type_display_name(room_data: RoomData) -> String:
	if room_data and room_data.room_definition:
		return room_data.room_definition.room_name
	return "Unknown Room"

func get_room_type_icon(room_data: RoomData) -> Texture2D:
	if room_data and room_data.room_definition:
		return room_data.room_definition.room_icon
	return null

# ============================================================================
# DEBUG TOOLS
# ============================================================================

func debug_print_status():
	"""Print current dungeon status"""
	print("\n=== DUNGEON STATUS ===")
	print("Current Rank: %d" % current_rank)
	print("Rooms visited this rank: %d" % rooms_visited_this_rank)
	print("Player rooms remaining: %d" % Player.rooms_remaining)
	print("Boss ready: %s" % (current_boss_enemy != null))
	if current_boss_enemy:
		print("  Boss: %s (HP: %d)" % [current_boss_enemy.enemy_name, current_boss_enemy.stats.hit_points])
	print("===================\n")

func debug_add_rooms(amount: int):
	"""Grant player bonus rooms"""
	Player.add_rooms(amount)

func debug_set_rank(rank: int):
	"""Jump to specific rank"""
	current_rank = rank
	await initialize_rank()
	print("[DungeonManager] DEBUG: Jumped to rank %d" % rank)
