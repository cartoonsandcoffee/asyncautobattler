extends Node

signal player_died()

signal inventory_updated(item: Item, slot_index: int)
signal status_updated(status: Enums.StatusEffects, amount: int)

var player_name: String = ""
var stats: GameStats
var status_effects: StatusEffects
var inventory: Inventory

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
	status_effects.status_updated.connect(_on_status_effect_updated)

	if stats:
		stats.agility = 0
		stats.damage = 0
		stats.shield = 0
		stats.gold = 50
		stats.strikes = 1
		stats.hit_points = 10
		stats.reset_to_base_values()
	
	if inventory:
		inventory.add_item(ItemsManager.available_items["Testing Shield"])
		inventory.add_item(ItemsManager.available_items["Fists"])
		inventory.add_item(ItemsManager.available_items["Liferoot Gauntlets"])
		inventory.add_item(ItemsManager.available_items["Testing Robes"])
		inventory.add_item(ItemsManager.available_items["Thorn Shield"])
		inventory.add_item(ItemsManager.available_items["Testing Boots"])

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

	if Player.inventory.weapon_slot:
		if Player.inventory.weapon_slot.damage_bonus != 0:
			stats.increase_base_stat(Enums.Stats.DAMAGE, Player.inventory.weapon_slot.damage_bonus)
		if Player.inventory.weapon_slot.shield_bonus != 0:
			stats.increase_base_stat(Enums.Stats.SHIELD, Player.inventory.weapon_slot.shield_bonus)
		if Player.inventory.weapon_slot.hit_points_bonus != 0:
			stats.increase_base_stat(Enums.Stats.HITPOINTS, Player.inventory.weapon_slot.hit_points_bonus)
		if Player.inventory.weapon_slot.agility_bonus != 0:
			stats.increase_base_stat(Enums.Stats.AGILITY, Player.inventory.weapon_slot.agility_bonus)

	stats.reset_to_base_values()

func _on_inventory_item_added(item: Item, slot_index: int):
	#print(item.item_name + " - slot: " + str(slot_index))
	inventory_updated.emit(item, slot_index)

func _on_status_effect_updated(_status: Enums.StatusEffects, amount: int):
	#print(item.item_name + " - slot: " + str(slot_index))
	status_updated.emit(_status, amount)

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
