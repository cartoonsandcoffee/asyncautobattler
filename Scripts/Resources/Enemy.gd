class_name Enemy
extends Resource

enum EnemyType {
	REGULAR,
	ELITE,
	BOSS_PLAYER   # Async multiplayer boss
}

# Basic properties
@export var enemy_id: String = ""
@export var enemy_name: String = "Unknown Enemy"
@export var enemy_type: EnemyType = EnemyType.REGULAR
@export_multiline var description: String = ""
@export var sprite: Texture2D
@export var sprite_hit: Texture2D
@export var sprite_attack: Texture2D
@export var sprite_color: Color = Color.WHITE
@export var weapon_sprite: Texture2D
@export var skin_id: int = 0
@export var skin_color: Color = Color.WHITE
@export var item_bundle:Array[int] = []

@export_group("Stats")
@export var stats: GameStats:
	get:
		if stats == null:
			stats = GameStats.new()
		return stats
	set(value):
		stats = value
@export var status_effects: StatusEffects:
	get:
		if status_effects == null:
			status_effects = StatusEffects.new()
		return status_effects
	set(value):
		status_effects = value	
@export var inventory: Inventory:
	get:
		if inventory == null:
			inventory = Inventory.new()
		return inventory
	set(value):
		inventory = value	

# Applied to current weapon (resets on weapon swap)
var current_weapon_stat_upgrades: Dictionary = {
	"damage": 0, 
	"shield": 0, 
	"agility": 0
}
var current_weapon_rule_upgrade: Item = null  # The enchantment item

# Rewards
@export_group("Rewards")
@export var gold: int = 3
@export var item_drop_chance: float = 0.1  # 10% chance
@export var possible_item_drops: Array[Item] = []

@export_group("Audio")
@export var approach_sound: AudioStream = null
@export var death_sound: AudioStream = null
@export var combat_music: AudioStream = null

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
	stats.strikes_left = stats.strikes
	stats.strikes_next_turn = stats.strikes
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
	
	# Add regular item bonuses
	for item in inventory.item_slots:
		if item:
			_apply_item_stat_bonuses(item)
	
	# Add weapon bonuses
	if inventory.weapon_slot:
		_apply_item_stat_bonuses(inventory.weapon_slot)

		# Apply weapon upgrades
		stats.increase_base_stat(Enums.Stats.DAMAGE, current_weapon_stat_upgrades["damage"])
		stats.increase_base_stat(Enums.Stats.SHIELD, current_weapon_stat_upgrades["shield"])
		stats.increase_base_stat(Enums.Stats.AGILITY, current_weapon_stat_upgrades["agility"])

	# Add set bonus item bonuses
	for bonus_item in SetBonusManager.get_active_set_bonuses(self):
		_apply_item_stat_bonuses(bonus_item)

	# apply any persistant/special item rules
	_apply_persistent_rules()
	
	# Reset current values to match new base values
	stats.reset_to_base_values()
	
func _apply_persistent_rules():
	# Collect all persistent rules from inventory
	var all_items = inventory.item_slots.duplicate()
	if inventory.weapon_slot:
		all_items.append(inventory.weapon_slot)
		if current_weapon_rule_upgrade:
			all_items.append(current_weapon_rule_upgrade)
	
	for bonus_item in SetBonusManager.get_active_set_bonuses(self):
		all_items.append(bonus_item)

	for item in all_items:
		if not item:
			continue
		
		for rule in item.rules:
			if rule.trigger_type != Enums.TriggerType.PERSISTENT:
				continue
			
			# Check condition if present
			if rule.has_condition:
				if not _evaluate_persistent_condition(rule):
					continue
			
			# Execute persistent effect based on special_string
			_execute_persistent_effect(rule, item)	

func _apply_item_stat_bonuses(item: Item):
	if item.damage_bonus != 0:
		stats.increase_base_stat(Enums.Stats.DAMAGE, item.damage_bonus)
	if item.shield_bonus != 0:
		stats.increase_base_stat(Enums.Stats.SHIELD, item.shield_bonus)
	if item.agility_bonus != 0:
		stats.increase_base_stat(Enums.Stats.AGILITY, item.agility_bonus)
	if item.hit_points_bonus != 0:
		stats.increase_base_stat(Enums.Stats.HITPOINTS, item.hit_points_bonus)
	if item.strikes_bonus != 0:
		stats.increase_base_stat(Enums.Stats.STRIKES, item.strikes_bonus)
	if item.burn_damage_bonus != 0:
		stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, item.burn_damage_bonus)

## ===================================================================================
## Persistent Item Rule Functions
## ===================================================================================

func _evaluate_persistent_condition(rule: ItemRule):
	# Evaluate conditions for persistent rules (out of combat context)
	# Uses Player stats since we're in exploration

	var entity_value = 0
	var compare_value = 0
	
	# Get condition entity value
	if rule.condition_type == ItemRule.StatOrStatus.STAT:
		match rule.condition_of:
			Enums.TargetType.SELF:
				entity_value = _get_persistent_stat_value(rule.condition_stat, Enums.StatType.CURRENT)
			Enums.TargetType.ENEMY:
				if !CombatManager.combat_active:
					return false
				entity_value = CombatManager.pass_enemy_stats(rule.condition_stat, Enums.StatType.CURRENT)
			_:
				return false  
	elif rule.condition_type == ItemRule.StatOrStatus.STATUS:
		if !CombatManager.combat_active:
			return false
		match rule.condition_of:
			Enums.TargetType.SELF:
				entity_value = status_effects.get_status_value(rule.condition_status)
			Enums.TargetType.ENEMY:
				entity_value = CombatManager.pass_enemy_status(rule.condition_status)
			_:
				return false 
	else:
		# Can't check status effects out of combat
		return false
	
	# Get comparison value
	match rule.compare_to:
		ItemRule.ConditionValueType.VALUE:
			compare_value = rule.condition_value
		ItemRule.ConditionValueType.STAT_VALUE:
			if rule.condition_to_party == Enums.TargetType.SELF:
				compare_value = _get_persistent_stat_value(rule.condition_party_stat, rule.condition_stat_type)
			elif rule.condition_to_party == Enums.TargetType.ENEMY:
				if !CombatManager.combat_active:
					return false
				compare_value = CombatManager.pass_enemy_stats(rule.condition_party_stat, rule.condition_stat_type)
			else:
				return false
		ItemRule.ConditionValueType.STATUS_VALUE:
			if !CombatManager.combat_active:
				return false
			if rule.condition_to_party == Enums.TargetType.SELF:
				compare_value = status_effects.get_status_value(rule.condition_party_status)
			elif rule.condition_to_party == Enums.TargetType.ENEMY:
				compare_value = CombatManager.pass_enemy_status(rule.condition_party_status)
			else:
				return false
		_:
			return false
	
	# Perform comparison
	return _compare_values(entity_value, rule.condition_comparison, compare_value)

func _compare_values(a: int, comparison: String, b: int) -> bool:
	match comparison:
		">": return a > b
		"<": return a < b
		">=": return a >= b
		"<=": return a <= b
		"==": return a == b
		"=": return a == b		
		"!=": return a != b
		_: return false

func _get_persistent_stat_value(stat: Enums.Stats, stat_type: Enums.StatType) -> int:
	match stat:
		Enums.Stats.HITPOINTS:
			if stat_type == Enums.StatType.CURRENT:
				return stats.hit_points_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.hit_points - stats.hit_points_current
			else:
				return stats.hit_points
		Enums.Stats.DAMAGE:
			if stat_type == Enums.StatType.CURRENT:
				return stats.damage_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.damage - stats.damage_current
			else:
				return stats.damage
		Enums.Stats.SHIELD:
			if stat_type == Enums.StatType.CURRENT:
				return stats.shield_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.shield - stats.shield_current
			else:
				return stats.shield
		Enums.Stats.AGILITY:
			if stat_type == Enums.StatType.CURRENT:
				return stats.agility_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.agility - stats.agility_current
			else:
				return stats.agility
		Enums.Stats.STRIKES:
			if stat_type == Enums.StatType.CURRENT:
				return stats.strikes_left
			elif stat_type == Enums.StatType.MISSING:
				return 0
			else:
				return stats.strikes_next_turn
		Enums.Stats.BURN_DAMAGE:
			if stat_type == Enums.StatType.CURRENT:
				return stats.burn_damage_current
			elif stat_type == Enums.StatType.MISSING:
				return stats.burn_damage - stats.burn_damage_current
			else:
				return stats.burn_damage
		_:
			return 0

func _execute_persistent_effect(rule: ItemRule, item: Item):
	# Handle special_string meta-mechanics
	if rule.special_string != "":
		_handle_special_string_persistent(rule.special_string)
		return
	
	# Handle standard persistent effects (stat modifications)
	if rule.effect_type == Enums.EffectType.MODIFY_STAT:
		var amount = _calculate_effect_amount(rule) * _calculate_execution_count(item)
		
		if rule.target_stat_type == Enums.StatType.BASE:
			# Apply to base stat
			match rule.target_stat:
				Enums.Stats.DAMAGE:
					stats.increase_base_stat(Enums.Stats.DAMAGE, amount)
				Enums.Stats.SHIELD:
					stats.increase_base_stat(Enums.Stats.SHIELD, amount)
				Enums.Stats.AGILITY:
					stats.increase_base_stat(Enums.Stats.AGILITY, amount)
				Enums.Stats.HITPOINTS:
					stats.increase_base_stat(Enums.Stats.HITPOINTS, amount)
				Enums.Stats.STRIKES:
					stats.increase_base_stat(Enums.Stats.STRIKES, amount)
				Enums.Stats.BURN_DAMAGE:
					stats.increase_base_stat(Enums.Stats.BURN_DAMAGE, amount)
		elif rule.target_stat_type == Enums.StatType.CURRENT:
			# Apply to current stat
			match rule.target_stat:
				Enums.Stats.DAMAGE:
					stats.increase_stat(Enums.Stats.DAMAGE, amount)
				Enums.Stats.SHIELD:
					stats.increase_stat(Enums.Stats.SHIELD, amount)
				Enums.Stats.AGILITY:
					stats.increase_stat(Enums.Stats.AGILITY, amount)
				Enums.Stats.HITPOINTS:
					stats.increase_stat(Enums.Stats.HITPOINTS, amount)
				Enums.Stats.STRIKES:
					stats.increase_stat(Enums.Stats.STRIKES, amount)
				Enums.Stats.BURN_DAMAGE:
					stats.increase_stat(Enums.Stats.BURN_DAMAGE, amount)

func _calculate_effect_amount(rule: ItemRule) -> int:
	# Calculate effect amount for persistent rules
	var amount = 0
	
	match rule.effect_of:
		ItemRule.ConditionValueType.VALUE:
			amount = rule.effect_amount
		ItemRule.ConditionValueType.STAT_VALUE:
			# Read from a stat (e.g., "gain HP equal to your shield")
			if rule.effect_stat_party == Enums.TargetType.SELF:
				amount = _get_persistent_stat_value(rule.effect_stat_value, rule.effect_stat_type)
			elif rule.effect_stat_party == Enums.TargetType.ENEMY:
				if !CombatManager.combat_active:
					return 0
				amount = CombatManager.pass_enemy_stats(rule.effect_stat_value, rule.effect_stat_type)
		ItemRule.ConditionValueType.STATUS_VALUE:
			if !CombatManager.combat_active:
				return 0
			if rule.effect_stat_party == Enums.TargetType.SELF:
				amount = status_effects.get_status_value(rule.effect_status_value)
			elif rule.effect_stat_party == Enums.TargetType.ENEMY:
				amount = CombatManager.pass_enemy_status(rule.effect_status_value)
		_:
			amount = 0
	
	return amount

func _calculate_execution_count(item: Item) -> int:
	# Calculate how many times to execute this effect.
	
	# Factors:
	# - Base: 1 time
	# - repeat_effect_X_times: Add X
	# - repeat_effect_for_category: Add count of items with that category

	var count = 1
	
	# Add fixed repeats
	count += item.repeat_rules_X_times
	
	# Add category-based repeats
	if item.repeat_rules_for_category != "":
		var category_count = inventory.count_items_with_category(item.repeat_rules_for_category)
		count += category_count
	
	# Check for persistent rules that might increase the repeats
	#count += _check_persistent_repeat_modifiers(source_entity, item)

	return maxi(count, 1)  # At least 1

func _handle_special_string_persistent(special: String):
	# Handle special meta-mechanics
	match special:
		"double_armor":
			stats.set_base_stat(Enums.Stats.SHIELD, stats.shield * 2)
		"double_shield":
			stats.set_base_stat(Enums.Stats.SHIELD, stats.shield * 2)
		"double_damage":
			#stats.set_base_stat(Enums.Stats.DAMAGE, stats.damage * 2)
			pass #JDM: Damage stat cannot be doubled outside combat.
		"double_hp":
			stats.set_base_stat(Enums.Stats.HITPOINTS, stats.hit_points * 2)
		"double_agility":
			stats.set_base_stat(Enums.Stats.AGILITY, stats.agility * 2)
		# Add more as needed
		_:
			print("Unknown special_string: ", special)
