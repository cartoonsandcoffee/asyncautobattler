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
var _last_random_room: RoomData = null

# Boss data (fetched from Supabase via existing BossHandler)
var current_boss_data: Dictionary = {}
var current_boss_enemy: Enemy = null

var _initialized: bool = false
var _bag: DungeonBag = DungeonBag.new()

var is_loaded_from_save: bool =  false

# ============================================================================
# SIGNALS
# ============================================================================

signal boss_loaded(boss: Enemy)
signal version_outdated(latest_version: String)

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

	#run_debug_simulations()

	print("[DungeonManager] Initialized - on-demand room generation")


func reset():
	current_rank = 1
	rooms_visited_this_rank = 0

	all_visited_rooms.clear()
	_bag.reset_for_new_run()

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

	var room_def = _bag.draw()
	
	if room_def == null:
		push_warning("[DungeonManager] Bag returned null — using fallback")
		return _get_fallback_room()
	
	var room_data = room_generator._create_room_data(room_def)
	room_generator._assign_combat_to_room(room_data)
	print("[DungeonManager] Generated room: %s (Rank %d)" % [room_def.room_name, current_rank])
	return room_data

func get_random_dungeon_room_OLD() -> RoomData:	#JDM: If new DungeonBag functionality works delete this whole function otherwise use to revert other func
	# Get available rooms for current rank
	var available_rooms = RoomRegistry.get_available_rooms_for_rank(current_rank)
	if available_rooms.is_empty():
		push_error("[DungeonManager] No rooms available for rank %d!" % current_rank)
		return _get_fallback_room()
	
	# Filter out same-type/same-rarity repeats for UTILITY and MERCHANT
	var filtered_rooms = available_rooms
	if _last_random_room != null:
		var last_def = _last_random_room.room_definition
		var restricted_types = [Enums.RoomType.UTILITY, Enums.RoomType.MERCHANT]

		## Make sure they don't encounter two of the same merchants or utilities in a row
		if last_def.room_type in restricted_types:
			filtered_rooms = available_rooms.filter(func(rd):
				return not (rd.room_type == last_def.room_type and rd.rarity == last_def.rarity)
			)
	
		## Don't show the merchants if they can't afford to buy anything.
		if Player.stats.gold < 3:
			filtered_rooms = available_rooms.filter(func(rd):
				return not (rd.room_type == Enums.RoomType.MERCHANT)
			)

		## Don't show the upgrade room if you already have all upgrades.
		if Player.all_weapon_upgrades_maxed():
			filtered_rooms = available_rooms.filter(func(rd):
				return not (rd.room_name == "Weapon Upgrade")
			)

		## Don't show super upgrades if player already used it
		if Player.super_upgrades_left <= 0:
			filtered_rooms = available_rooms.filter(func(rd):
				return not (rd.room_name == "Ancient Hall")
			)

		## Don't show scorpion encounter if player already used it
		if Player.scorpion_encounters_left <= 0:
			filtered_rooms = available_rooms.filter(func(rd):
				return not (rd.room_name == "An Insect Nest")
			)

		# Only use filter if it leaves valid options
		if filtered_rooms.is_empty():
			filtered_rooms = available_rooms

	var room_def = room_generator._pick_weighted_room(filtered_rooms)
	var room_data = room_generator._create_room_data(room_def)
	room_generator._assign_combat_to_room(room_data)
	
	_last_random_room = room_data
	
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
	_last_random_room = room_data
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
	SaveManager.save_run()

	print("[DungeonManager] Room completed: %s. Total this rank: %d, Player rooms: %d" % [
		room_data.room_definition.room_name if room_data else "Unknown",
		rooms_visited_this_rank,
		Player.rooms_left_this_rank
	])

func exhaust_room(room_name: String):
	# Called for rooms that are once per run, or exhaustable
	_bag.exhaust_room(room_name)

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
	
	# VERSION CHECK: Only on rank 1, first boss of the run
	if current_rank == 1 and not current_boss_data.is_empty():
		var boss_version = current_boss_data.get("game_version", "0.0.0")
		if Player.is_version_outdated(Player.GAME_VERSION, boss_version):
			print("[DungeonManager] X Client outdated! Current: %s, Boss: %s" % [Player.GAME_VERSION, boss_version])
			version_outdated.emit(boss_version)
			# Still load the boss, just warn the player
		else:
			print("[DungeonManager] OK! Version check passed: %s >= %s" % [Player.GAME_VERSION, boss_version])


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
	if Player.inventory.unlocked_slots < Player.inventory.TOTAL_SLOTS:
		Player.inventory.expand_inventory(2)
		print("[DungeonManager] Rank %d! Inventory expanded to %d slots" % [
			current_rank, 
			Player.inventory.unlocked_slots
		])
	
	# Clear old boss data
	current_boss_data = {}
	current_boss_enemy = null
	
	# Initialize new rank
	await initialize_rank()
	_bag.advance_rank(current_rank)

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

func debug_simulate_rank(rank: int, draws: int = 30) -> void:
	_bag.build_for_rank(rank)
	print("\n=== SIMULATING RANK %d (%d draws) ===" % [rank, draws])
	var counts: Dictionary = {}
	for i in range(draws):
		var room_def = _bag.draw()
		var name = room_def.room_name if room_def != null else "FALLBACK"
		counts[name] = counts.get(name, 0) + 1
		print("  [%d] %s" % [i + 1, name])
	print("\n--- FREQUENCY ---")
	for room_name in counts:
		print("  %s: %d" % [room_name, counts[room_name]])
	print("=================\n")

func run_debug_simulations():
	debug_simulate_rank(3, 15)  # Check rank 3 weights
	debug_simulate_rank(4, 20)  # Check rank 3 weights
	debug_simulate_rank(5, 30)  # Check rank 3 weights
	debug_simulate_rank(6, 40)  # Check rank 3 weights	