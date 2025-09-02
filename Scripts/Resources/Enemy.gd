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
@export var inventory: Inventory

# Rewards
@export_group("Rewards")
@export var gold: int = 3
@export var item_drop_chance: float = 0.1  # 10% chance
@export var possible_item_drops: Array[Item] = []

# Combat behavior
@export_group("Combat Rules")
@export var combat_rules: Array[ItemRule] = []

# Special abilities (using same rule system as items)
@export_group("Special Abilities")
@export var abilities: Array[EnemyAbility] = []

# Combat state tracking
var exposed_triggered: bool = false
var wounded_triggered: bool = false
var turn_count: int = 0

func _init():
	stats = GameStats.new()
	inventory = Inventory.new()
	status_effects = StatusEffects.new()
	reset_to_base_values()

func reset_to_base_values():
	"""Reset current values to base values for new combat"""
	stats.damage_current = stats.damage
	stats.shield_current = stats.shield
	stats.agility_current = stats.agility
	stats.hit_points_current = stats.hit_points
	
	# Reset status effects
	status_effects = StatusEffects.new()
	
	# Reset combat flags
	exposed_triggered = false
	wounded_triggered = false
	turn_count = 0

func take_damage(amount: int) -> int:
	"""Take damage, affecting shield first then HP"""
	var remaining_damage = amount
	
	# Apply to shield first
	if stats.shield_current > 0:
		var shield_absorbed = min(stats.shield_current, remaining_damage)
		stats.shield_current -= shield_absorbed
		remaining_damage -= shield_absorbed
		
		# Check for exposed trigger
		if stats.shield_current == 0 and not exposed_triggered:
			exposed_triggered = true
			trigger_exposed_abilities()
	
	# Apply remaining damage to HP
	if remaining_damage > 0:
		stats.hit_points_current -= remaining_damage
		
		# Check for wounded trigger
		if stats.hit_points_current <= stats.hit_points / 2 and not wounded_triggered:
			wounded_triggered = true
			trigger_wounded_abilities()
	
	return amount  # Return actual damage dealt

func is_alive() -> bool:
	return stats.hit_points_current > 0

func get_gold_reward() -> int:
	return gold

func get_item_drop() -> Item:
	"""Roll for item drop"""
	if randf() <= item_drop_chance and not possible_item_drops.is_empty():
		return possible_item_drops[randi() % possible_item_drops.size()]
	return null

func trigger_battle_start_abilities():
	"""Trigger all battle start abilities"""
	for ability in abilities:
		if ability.trigger == Enums.TriggerType.BATTLE_START:
			apply_ability(ability)

func trigger_turn_start_abilities():
	"""Trigger all turn start abilities"""
	turn_count += 1
	
	for ability in abilities:
		if ability.trigger == Enums.TriggerType.TURN_START:
			apply_ability(ability)
		elif ability.trigger == Enums.TriggerType.EVERY_OTHER_TURN:
			if turn_count % 2 == 0:
				apply_ability(ability)
		elif ability.trigger == Enums.TriggerType.EVERY_X_TURNS:
			if turn_count % ability.turn_interval == 0:
				apply_ability(ability)

func trigger_on_hit_abilities():
	"""Trigger abilities when enemy hits player"""
	for ability in abilities:
		if ability.trigger == Enums.TriggerType.ON_HIT:
			apply_ability(ability)

func trigger_exposed_abilities():
	"""Trigger abilities when shield breaks"""
	for ability in abilities:
		if ability.trigger == Enums.TriggerType.EXPOSED:
			apply_ability(ability)

func trigger_wounded_abilities():
	"""Trigger abilities when HP drops below 50%"""
	for ability in abilities:
		if ability.trigger == Enums.TriggerType.WOUNDED:
			apply_ability(ability)

func apply_ability(ability: EnemyAbility):
	"""Apply an ability effect"""
	match ability.effect_type:
		EnemyAbility.EffectType.DAMAGE_BOOST:
			stats.damage_current += ability.value
		EnemyAbility.EffectType.SHIELD_GAIN:
			stats.shield_current += ability.value
		EnemyAbility.EffectType.HEAL:
			stats.hit_points_current = min(stats.hit_points_current + ability.value, stats.hit_points)
		EnemyAbility.EffectType.APPLY_POISON:
			# This would apply to player
			pass
		EnemyAbility.EffectType.APPLY_BURN:
			# This would apply to player
			pass
		# Add more effect types as needed

func process_status_effects():
	"""Process status effects at turn start"""
	# Poison
	if status_effects.poison > 0:
		if stats.shield_current == 0:  # Poison only affects if no shield
			stats.hit_points_current -= status_effects.poison
		status_effects.poison -= 1
	
	# Burn
	if status_effects.burn > 0:
		var burn_damage = status_effects.burn * stats.burn_damage_current  # Base burn damage
		take_damage(burn_damage)
		status_effects.burn -= 1
	
	# Regeneration
	if status_effects.regeneration > 0:
		stats.hit_points_current = min(stats.hit_points_current + status_effects.regeneration, stats.hit_points)
		status_effects.regeneration -= 1
	
	# Acid (reduces shield)
	if status_effects.acid > 0 and stats.shield_current > 0:
		stats.shield_current = max(0, stats.shield_current - status_effects.acid)

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
