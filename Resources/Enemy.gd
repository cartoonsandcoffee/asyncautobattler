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
@export var sprite_color: Color = Color.WHITE
@export var weapon_sprite: Texture2D

@export_group("Stats")
@export var stats: GameStats
@export var status_effects: StatusEffects


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

	reset_to_base_values()

func reset_to_base_values():
	stats.damage_current = stats.damage
	stats.shield_current = stats.shield
	stats.agility_current = stats.agility
	stats.hit_points_current = stats.hit_points
	
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
