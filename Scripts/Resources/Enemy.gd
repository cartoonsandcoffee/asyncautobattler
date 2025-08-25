class_name Enemy
extends Resource

enum EnemyType {
	GOBLIN,
	GHOUL,
	ROYAL_GUARD,
	SLIME,
	GOLEM,
	WITCH_QUEEN,  # Elite
	BOSS_PLAYER   # Async multiplayer boss
}

# Basic properties
@export var enemy_name: String = "Unknown Enemy"
@export var enemy_type: EnemyType = EnemyType.GOBLIN
@export_multiline var description: String = ""
@export var is_elite: bool = false
@export var sprite: Texture2D
@export var sprite_color: Color = Color.WHITE


@export_group("Base Stats")
@export var damage: int = 0
@export var shield: int = 0
@export var agility: int = 0
@export var hit_points: int = 10
@export var strikes: int = 1

# Current values (for combat)
var damage_current: int = 0
var shield_current: int = 0
var agility_current: int = 0
var hit_points_current: int = 10

# Status effects (same as player)
var status_effects: StatusEffects

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
	status_effects = StatusEffects.new()
	reset_to_base_values()

func reset_to_base_values():
	"""Reset current values to base values for new combat"""
	damage_current = damage
	shield_current = shield
	agility_current = agility
	hit_points_current = hit_points
	
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
	if shield_current > 0:
		var shield_absorbed = min(shield_current, remaining_damage)
		shield_current -= shield_absorbed
		remaining_damage -= shield_absorbed
		
		# Check for exposed trigger
		if shield_current == 0 and not exposed_triggered:
			exposed_triggered = true
			trigger_exposed_abilities()
	
	# Apply remaining damage to HP
	if remaining_damage > 0:
		hit_points_current -= remaining_damage
		
		# Check for wounded trigger
		if hit_points_current <= hit_points / 2 and not wounded_triggered:
			wounded_triggered = true
			trigger_wounded_abilities()
	
	return amount  # Return actual damage dealt

func is_alive() -> bool:
	return hit_points_current > 0

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
		if ability.trigger == EnemyAbility.TriggerType.BATTLE_START:
			apply_ability(ability)

func trigger_turn_start_abilities():
	"""Trigger all turn start abilities"""
	turn_count += 1
	
	for ability in abilities:
		if ability.trigger == EnemyAbility.TriggerType.TURN_START:
			apply_ability(ability)
		elif ability.trigger == EnemyAbility.TriggerType.EVERY_OTHER_TURN:
			if turn_count % 2 == 0:
				apply_ability(ability)
		elif ability.trigger == EnemyAbility.TriggerType.EVERY_X_TURNS:
			if turn_count % ability.turn_interval == 0:
				apply_ability(ability)

func trigger_on_hit_abilities():
	"""Trigger abilities when enemy hits player"""
	for ability in abilities:
		if ability.trigger == EnemyAbility.TriggerType.ON_HIT:
			apply_ability(ability)

func trigger_exposed_abilities():
	"""Trigger abilities when shield breaks"""
	for ability in abilities:
		if ability.trigger == EnemyAbility.TriggerType.EXPOSED:
			apply_ability(ability)

func trigger_wounded_abilities():
	"""Trigger abilities when HP drops below 50%"""
	for ability in abilities:
		if ability.trigger == EnemyAbility.TriggerType.WOUNDED:
			apply_ability(ability)

func apply_ability(ability: EnemyAbility):
	"""Apply an ability effect"""
	match ability.effect_type:
		EnemyAbility.EffectType.DAMAGE_BOOST:
			damage_current += ability.value
		EnemyAbility.EffectType.SHIELD_GAIN:
			shield_current += ability.value
		EnemyAbility.EffectType.HEAL:
			hit_points_current = min(hit_points_current + ability.value, hit_points)
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
		if shield_current == 0:  # Poison only affects if no shield
			hit_points_current -= status_effects.poison
		status_effects.poison -= 1
	
	# Burn
	if status_effects.burn > 0:
		var burn_damage = status_effects.burn * 3  # Base burn damage
		take_damage(burn_damage)
		status_effects.burn -= 1
	
	# Regeneration
	if status_effects.regeneration > 0:
		hit_points_current = min(hit_points_current + status_effects.regeneration, hit_points)
		status_effects.regeneration -= 1
	
	# Acid (reduces shield)
	if status_effects.acid > 0 and shield_current > 0:
		shield_current = max(0, shield_current - status_effects.acid)

func create_scaled_version(difficulty_multiplier: float) -> Enemy:
	"""Create a scaled version based on difficulty"""
	var scaled = duplicate(true) as Enemy
	
	scaled.hit_points = int(hit_points * difficulty_multiplier)
	scaled.damage = int(damage * difficulty_multiplier)
	scaled.shield = int(shield * difficulty_multiplier)
	scaled.agility = int(agility * difficulty_multiplier)
	
	# Scale rewards too
	scaled.gold = int(gold * difficulty_multiplier)
	
	scaled.reset_to_base_values()
	return scaled

func get_display_name() -> String:
	"""Get display name with elite status"""
	if is_elite:
		return "Elite " + enemy_name
	return enemy_name