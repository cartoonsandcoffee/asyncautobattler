extends Node

signal player_died()
signal player_leveled_up()
signal stats_updated()

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

	if stats:
		stats.agility = 0
		stats.damage = 0
		stats.shield = 0
		stats.gold = 5
		stats.strikes = 1
		stats.hit_points = 10
		stats.reset_to_base_values()
	
	if inventory:
		inventory.add_item(ItemsManager.available_items["Holy Shield"])
		inventory.add_item(ItemsManager.available_items["Fists"])
		inventory.add_item(ItemsManager.available_items["Liferoot Gauntlets"])
		inventory.add_item(ItemsManager.available_items["Rusted Plate"])
		inventory.add_item(ItemsManager.available_items["Testing Boots"])
		inventory.add_item(ItemsManager.available_items["Testing Boots"])
		inventory.add_item(ItemsManager.available_items["Testing Boots"])
		inventory.add_item(ItemsManager.available_items["Testing Boots"])
		inventory.add_item(ItemsManager.available_items["Testing Boots"])

func update_stats_from_items():
	reset_stats()

	for item in Player.inventory.item_slots:
		if item:
			if item.damage_bonus != 0:
				stats.damage += item.damage_bonus
			if item.shield_bonus != 0:
				stats.shield += item.shield_bonus
			if item.hit_points_bonus != 0:
				stats.hit_points += item.hit_points_bonus
			if item.agility_bonus != 0:
				stats.agility += item.agility_bonus

	if Player.inventory.weapon_slot:
		if Player.inventory.weapon_slot.damage_bonus != 0:
			stats.damage += Player.inventory.weapon_slot.damage_bonus
		if Player.inventory.weapon_slot.shield_bonus != 0:
			stats.shield += Player.inventory.weapon_slot.shield_bonus
		if Player.inventory.weapon_slot.hit_points_bonus != 0:
			stats.hit_points += Player.inventory.weapon_slot.hit_points_bonus
		if Player.inventory.weapon_slot.agility_bonus != 0:
			stats.agility += Player.inventory.weapon_slot.agility_bonus

	stats_updated.emit()

func reset_stats():
	if stats:
		stats.agility = 0
		stats.damage = 0
		stats.shield = 0
		stats.strikes = 1
		stats.hit_points = 10
