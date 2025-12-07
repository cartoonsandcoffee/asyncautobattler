extends Node

signal player_died()

signal inventory_updated(item: Item, slot_index: int)

var player_uuid: String = ""
var player_name: String = ""
var stats: GameStats
var status_effects: StatusEffects
var inventory: Inventory
var skin_id: int = 0

# Entity state flags
var is_player: bool = false
var has_taken_turn_this_combat: bool = false
var exposed_triggered: bool = false
var wounded_triggered: bool = false

# Run-specific data (resets each run)
var current_rank: int = 1
var current_room: int = 1
var rooms_cleared_this_run: int = 0
var enemies_defeated_this_run: int = 0
var gold_earned_this_run: int = 0
var damage_dealt_this_run: int = 0
var damage_taken_this_run: int = 0

# Run state tracking
var run_start_time: float = 0.0
var max_gold_this_run: int = 0
var items_found_this_run: int = 0

func new_run(nm: String):
	player_name = nm
	stats = GameStats.new()
	inventory = Inventory.new()
	status_effects = StatusEffects.new()
	
	inventory.item_added.connect(_on_inventory_item_added)

	if stats:
		stats.agility = 0
		stats.damage = 0
		stats.shield = 0
		stats.gold = 50
		stats.strikes = 1
		stats.hit_points = 10
		stats.reset_to_base_values()
	
	if inventory:
		set_test_inventory()

	current_rank = 1
	current_room = 1
	rooms_cleared_this_run = 0
	enemies_defeated_this_run = 0
	gold_earned_this_run = 0
	damage_dealt_this_run = 0
	damage_taken_this_run = 0

	# Run state tracking
	run_start_time = 0.0
	max_gold_this_run = 0
	items_found_this_run = 0

func set_test_inventory():
	if !inventory:
		return

	inventory.set_inventory_size(12)

	# -- for testing basic rules

	inventory.add_item(ItemsManager.available_items["crude_blade"])
	inventory.add_item(ItemsManager.available_items["test_relic"])
	inventory.add_item(ItemsManager.available_items["testing_boots"])
	inventory.add_item(ItemsManager.available_items["testing_robes"])

	#inventory.add_item(ItemsManager.available_items["Tower Shield"])
	#inventory.add_item(ItemsManager.available_items["Fists"])
	#inventory.add_item(ItemsManager.available_items["Liferoot Gauntlets"])
	#inventory.add_item(ItemsManager.available_items["Testing Shield"])
	#inventory.add_item(ItemsManager.available_items["Thorn Shield"])

	# -- More complex set for testing detailed rules
	#inventory.add_item(ItemsManager.available_items["Clearmetal Dagger"])
	#inventory.add_item(ItemsManager.available_items["Metallic Glass"])
	#inventory.add_item(ItemsManager.available_items["Ironskin Potion"])
	#inventory.add_item(ItemsManager.available_items["Clearmetal Crown"])
	#inventory.add_item(ItemsManager.available_items["Reinforced Gauntlets"])
	#inventory.add_item(ItemsManager.available_items["Chainmail Shirt"])
	#inventory.add_item(ItemsManager.available_items["Metalliglass Totem"])
	#inventory.add_item(ItemsManager.available_items["Metalliglass Timepiece"])
	#inventory.add_item(ItemsManager.available_items["Diamond Double Plated Armor"])
	#inventory.add_item(ItemsManager.available_items["Potion of Insecurity"])
	#inventory.add_item(ItemsManager.available_items["Indecent Exposure"])
	#inventory.add_item(ItemsManager.available_items["Golden Battleworn Shield"])
	#inventory.add_item(ItemsManager.available_items["Clearmetal Battle Horn"])


func update_stats_from_items():
	stats.reset_base_stats()

	for item in Player.inventory.item_slots:
		if item:
			if item.damage_bonus != 0:
				stats.increase_base_stat(Enums.Stats.DAMAGE, item.damage_bonus)
			if item.shield_bonus != 0:
				stats.increase_base_stat(Enums.Stats.SHIELD, item.shield_bonus)
			if item.hit_points_bonus != 0:
				stats.increase_base_stat(Enums.Stats.HITPOINTS, item.hit_points_bonus)
			if item.agility_bonus != 0:
				stats.increase_base_stat(Enums.Stats.AGILITY, item.agility_bonus)
			if item.strikes_bonus != 0:
				stats.increase_base_stat(Enums.Stats.STRIKES, item.strikes_bonus)
			if item.burn_damage_bonus != 0:
				stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, item.burn_damage_bonus)

	if Player.inventory.weapon_slot:
		if Player.inventory.weapon_slot.damage_bonus != 0:
			stats.increase_base_stat(Enums.Stats.DAMAGE, Player.inventory.weapon_slot.damage_bonus)
		if Player.inventory.weapon_slot.shield_bonus != 0:
			stats.increase_base_stat(Enums.Stats.SHIELD, Player.inventory.weapon_slot.shield_bonus)
		if Player.inventory.weapon_slot.hit_points_bonus != 0:
			stats.increase_base_stat(Enums.Stats.HITPOINTS, Player.inventory.weapon_slot.hit_points_bonus)
		if Player.inventory.weapon_slot.agility_bonus != 0:
			stats.increase_base_stat(Enums.Stats.AGILITY, Player.inventory.weapon_slot.agility_bonus)
		if Player.inventory.weapon_slot.strikes_bonus != 0:
			stats.increase_base_stat(Enums.Stats.STRIKES, Player.inventory.weapon_slot.strikes_bonus)
		if Player.inventory.weapon_slot.burn_damage_bonus != 0:
			stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, Player.inventory.weapon_slot.burn_damage_bonus)

	stats.reset_to_base_values()

func _on_inventory_item_added(item: Item, slot_index: int):
	#print(item.item_name + " - slot: " + str(slot_index))
	inventory_updated.emit(item, slot_index)

func add_gold(value: int):
	Player.stats.gold += value
	Player.max_gold_this_run += value
	stats.stats_updated.emit()

func subtract_gold(value: int):
	if Player.stats.gold >= value:
		Player.stats.gold -= value
		stats.stats_updated.emit()
	else:	
		return false

func generate_or_load_uuid() -> String:
	if player_uuid.is_empty():
		# Simple approach: Use OS process ID + timestamp + random
		var timestamp = Time.get_unix_time_from_system()
		var random_part = randi() % 100000
		
		# Format as UUID-like string
		player_uuid = "%08x-%04x-%04x-%04x-%012x" % [
			OS.get_process_id(),
			int(timestamp) % 65536,
			4096 + (randi() % 4096),  # Version 4
			32768 + (randi() % 16384),  # Variant
			random_part
		]
		
		print("[Player] Generated UUID: %s" % player_uuid)
	return player_uuid

func to_boss_data() -> Dictionary:
	return {
		"player_id": generate_or_load_uuid(),
		"username": player_name,
		"skin_id": skin_id,
		"rank": DungeonManager.current_rank,
		"max_hp": stats.hit_points,
		"curr_hp": stats.hit_points_current,
		"base_damage": stats.damage,
		"shield": stats.shield,
		"agility": stats.agility,
		"strikes": stats.strikes,
		"burn_damage": stats.burn_damage,
		"gold": stats.gold,
		"inventory": _serialize_inventory(),
		"weapon": _serialize_weapon()
	}

func _serialize_inventory() -> Array:
	var inv = []
	for i in range(inventory.item_slots.size()):
		var item = inventory.item_slots[i]
		if item and not item.item_id.is_empty():
			inv.append({"id": item.item_id, "slot": i, "name": item.item_name})
	return inv

func _serialize_weapon() -> Dictionary:
	if inventory.weapon_slot and not inventory.weapon_slot.item_id.is_empty():
		return {"id": inventory.weapon_slot.item_id, "name": inventory.weapon_slot.item_name}
	return {}