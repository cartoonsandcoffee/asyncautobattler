class_name Enemy
extends Resource

enum EnemyType {
	REGULAR,
	ELITE,
	BOSS_PLAYER   # Async multiplayer boss
}

# Basic properties
@export var enemy_name: String = "Unknown Enemy"
@export var enemy_type: EnemyType = EnemyType.REGULAR
@export_multiline var description: String = ""
@export var sprite: Texture2D
@export var sprite_hit: Texture2D
@export var sprite_attack: Texture2D
@export var sprite_color: Color = Color.WHITE
@export var weapon_sprite: Texture2D
@export var skin_id: int = 0

@export_group("Stats")
@export var stats: GameStats
@export var status_effects: StatusEffects
@export var inventory: Inventory

# Rewards
@export_group("Rewards")
@export var gold: int = 3
@export var item_drop_chance: float = 0.1  # 10% chance
@export var possible_item_drops: Array[Item] = []


# Special abilities (using same rule system as items)
@export_group("Special Abilities")
@export var abilities: Array[Item] = []

# Combat state tracking
var exposed_triggered: bool = false
var wounded_triggered: bool = false
var turn_count: int = 0

func _init():
	stats = GameStats.new()
	status_effects = StatusEffects.new()
	inventory = Inventory.new()

	reset_to_base_values()

func reset_to_base_values():
	stats.damage_current = stats.damage
	stats.shield_current = stats.shield
	stats.agility_current = stats.agility
	stats.hit_points_current = stats.hit_points
	stats.strikes_current = stats.strikes
	stats.burn_damage_current = stats.burn_damage

	# Reset status effects
	status_effects.reset_statuses()
	
	# Reset combat flags
	exposed_triggered = false
	wounded_triggered = false
	turn_count = 0

func is_alive() -> bool:
	return stats.hit_points_current > 0

func get_gold_reward() -> int:
	return gold

func get_item_drop() -> Item:
	"""Roll for item drop"""
	if randf() <= item_drop_chance and not possible_item_drops.is_empty():
		return possible_item_drops[randi() % possible_item_drops.size()]
	return null

func create_scaled_version(difficulty_multiplier: float) -> Enemy:
	"""Create a scaled version based on difficulty"""
	var scaled = duplicate(true) as Enemy
	
	scaled.stats.hit_points = int(stats.hit_points * stats.difficulty_multiplier)
	scaled.stats.damage = int(stats.damage * stats.difficulty_multiplier)
	scaled.stats.shield = int(stats.shield * stats.difficulty_multiplier)
	scaled.stats.agility = int(stats.agility * stats.difficulty_multiplier)
	
	# Scale rewards too
	scaled.stats.gold = int(stats.gold * difficulty_multiplier)
	
	scaled.reset_to_base_values()
	return scaled

func get_display_name() -> String:
	"""Get display name with elite status"""
	if enemy_type == EnemyType.ELITE:
		return "Elite " + enemy_name
	return enemy_name

func get_all_items() -> Array[Item]:
	"""Get all items from both inventory and legacy abilities array."""
	var all_items: Array[Item] = []
	
	# Add from inventory if present
	if inventory:
		if inventory.weapon_slot:
			all_items.append(inventory.weapon_slot)
		for item in inventory.item_slots:
			if item:
				all_items.append(item)
	
	# Add from legacy abilities for backward compatibility
	for ability in abilities:
		if ability:
			all_items.append(ability)
	
	return all_items

func update_stats_from_items():
	# Calculate stats from equipped items (same as Player).
	# Call this after loading boss inventory from Supabase.
	
	# Only apply item stats if enemy has inventory system
	if not inventory:
		return
	
	# Reset to base stats first
	stats.reset_base_stats()
	
	# Apply item bonuses from inventory slots
	for item in inventory.item_slots:
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
	
	# Apply weapon bonuses
	if inventory.weapon_slot:
		if inventory.weapon_slot.damage_bonus != 0:
			stats.increase_base_stat(Enums.Stats.DAMAGE, inventory.weapon_slot.damage_bonus)
		if inventory.weapon_slot.shield_bonus != 0:
			stats.increase_base_stat(Enums.Stats.SHIELD, inventory.weapon_slot.shield_bonus)
		if inventory.weapon_slot.hit_points_bonus != 0:
			stats.increase_base_stat(Enums.Stats.HITPOINTS, inventory.weapon_slot.hit_points_bonus)
		if inventory.weapon_slot.agility_bonus != 0:
			stats.increase_base_stat(Enums.Stats.AGILITY, inventory.weapon_slot.agility_bonus)
		if inventory.weapon_slot.strikes_bonus != 0:
			stats.increase_base_stat(Enums.Stats.STRIKES, inventory.weapon_slot.strikes_bonus)
		if inventory.weapon_slot.burn_damage_bonus != 0:
			stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, inventory.weapon_slot.burn_damage_bonus)
	
	# Reset current values to match new base values
	stats.reset_to_base_values()
	
	print("[Enemy] Stats updated from items: HP=%d, DMG=%d, Shield=%d, Agi=%d, Strikes=%d" % [
		stats.hit_points,
		stats.damage,
		stats.shield,
		stats.agility,
		stats.strikes
	])