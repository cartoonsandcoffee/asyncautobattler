class_name CombatEffectExecutor
extends Node

## Executes ItemRule effects
## Handles dynamic values, conversions, meta-triggers, and all effect types

var combat_manager
var stat_handler: CombatStatHandler
var status_handler: CombatStatusHandler
var condition_evaluator: CombatConditionEvaluator
var damage_system: CombatDamageSystem

# Recursion protection for meta-triggers
const MAX_RECURSION_DEPTH = 3
var current_recursion_depth = 0

func _init(manager, stat_handler_ref: CombatStatHandler, status_handler_ref: CombatStatusHandler, 
		   condition_eval: CombatConditionEvaluator, damage_sys: CombatDamageSystem):
	combat_manager = manager
	stat_handler = stat_handler_ref
	status_handler = status_handler_ref
	condition_evaluator = condition_eval
	damage_system = damage_sys

# ===== MAIN ENTRY POINT =====

func execute_item_rule(item: Item, rule: ItemRule, source_entity, target_entity):
	# Execute a single ItemRule's effect.
	
	# IMPORTANT: This function is called for EACH rule in an item's rule list.
	# If a rule has a condition that fails, it returns a failure signal.
	# The caller (process_entity_items_sequentially) can use this to stop processing
	# subsequent rules on the same item.
	
	# Flow:
	# 1. Evaluate condition (if any)
	# 2. Calculate repeat count (repeat_effect_X_times, repeat_effect_for_category)
	# 3. Execute effect multiple times if needed
	# 4. Handle recursion for meta-triggers
	
	# Returns: true if executed successfully, false if condition failed

	# Check condition
	if not condition_evaluator.evaluate_condition(rule, source_entity, target_entity):
		combat_manager.add_to_combat_log_string("    ❌ Condition not met: " + condition_evaluator.condition_to_string(rule), Color.GRAY)
		return false  # Condition failed - signal to stop processing this item's rules
	
	# Calculate how many times to execute
	var execution_count = _calculate_execution_count(item, rule, source_entity)
	
	# Execute the effect (possibly multiple times)
	for i in range(execution_count):
		await _execute_effect_once(item, rule, source_entity, target_entity)
		
		# Small delay between repeats
		if i < execution_count - 1:
			await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc") * 0.3)
	
	return true  # Executed successfully

# ===== EXECUTION COUNT =====

func _calculate_execution_count(item: Item, rule: ItemRule, source_entity) -> int:
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
		var category_count = combat_manager.item_processor.count_items_with_category(source_entity, item.repeat_rules_for_category)
		count += category_count
	
	return maxi(count, 1)  # At least 1

# ===== EFFECT EXECUTION =====

func _execute_effect_once(item: Item, rule: ItemRule, source_entity, target_entity):
	# Execute a single instance of the effect.
	
	# Determine the actual target entity based on rule.target_type
	var actual_target = _get_target_entity(rule.target_type, source_entity)
	
	# Execute based on effect type
	match rule.effect_type:
		Enums.EffectType.MODIFY_STAT:
			await _execute_modify_stat(rule, source_entity, actual_target)
		
		Enums.EffectType.APPLY_STATUS:
			await _execute_apply_status(rule, source_entity, actual_target)
		
		Enums.EffectType.REMOVE_STATUS:
			await _execute_remove_status(rule, source_entity, actual_target)
		
		Enums.EffectType.DEAL_DAMAGE:
			await _execute_deal_damage(rule, source_entity, actual_target, item)
		
		Enums.EffectType.HEAL:
			await _execute_heal(rule, source_entity, actual_target)
		
		Enums.EffectType.CONVERT:
			await _execute_conversion(rule, source_entity)
		
		Enums.EffectType.TRIGGER_OTHER_ITEMS:
			await _execute_meta_trigger(rule, source_entity)

# ===== INDIVIDUAL EFFECT TYPES =====

func _execute_modify_stat(rule: ItemRule, source_entity, target_entity):
	"""Modify a stat (CURRENT or BASE)."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity)
	
	# Apply to stat handler
	stat_handler.modify_stat(target_entity, rule.target_stat, amount, rule.target_stat_type)
	
	# Note: stat_handler.change_stat() will emit signals and trigger items automatically

func _execute_apply_status(rule: ItemRule, source_entity, target_entity):
	"""Apply a status effect."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity)
	
	# Apply through status handler
	status_handler.apply_status(target_entity, rule.target_status, amount)

func _execute_remove_status(rule: ItemRule, source_entity, target_entity):
	"""Remove a status effect."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity)
	
	# Remove through status handler
	status_handler.remove_status(target_entity, rule.target_status, amount)

func _execute_deal_damage(rule: ItemRule, source_entity, target_entity, item: Item):
	"""Deal direct damage."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity)
	
	# Deal damage through damage system
	await damage_system.apply_damage(target_entity, amount, item, "item")

func _execute_heal(rule: ItemRule, source_entity, target_entity):
	"""Heal HP."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity)
	
	# Heal through damage system
	await damage_system.heal_entity(target_entity, amount)

func _execute_conversion(rule: ItemRule, source_entity):
	# Execute a CONVERT effect.
	
	# Conversions are atomic operations that convert one resource to another.
	# IMPORTANT: If the entity doesn't have enough source resource, conversion FAILS.
	
	# Examples:
	# - Convert 1 armor to 1 attack
	# - Convert 50% of poison stacks to damage
	# - Convert all thorns to regen

	# Determine FROM amount
	var from_amount = _calculate_conversion_amount(rule, source_entity)
	
	if from_amount <= 0:
		combat_manager.add_to_combat_log_string("    ⚠ Conversion failed: No source resource available", Color.GRAY)
		return
	
	# Validate we have enough source resource
	if not _validate_conversion_source(rule, source_entity, from_amount):
		var from_name = ""
		if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
			from_name = Enums.get_stat_string(rule.convert_from_stat)
		else:
			from_name = Enums.get_status_string(rule.convert_from_status)
		
		combat_manager.add_to_combat_log_string("    ⚠ Conversion failed: Not enough %s (need %d)" % [from_name, from_amount], Color.GRAY)
		return
	
	# Remove FROM resource
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
		stat_handler.modify_stat(from_entity, rule.convert_from_stat, -from_amount, Enums.StatType.CURRENT)
	else:  # STATUS
		var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
		status_handler.remove_status(from_entity, rule.convert_from_status, from_amount)
	
	# Calculate TO amount (apply conversion ratio)
	var to_amount = int(from_amount * rule.conversion_ratio)
	
	# Add TO resource
	if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
		var to_entity = _get_target_entity(rule.convert_to_party, source_entity)
		stat_handler.modify_stat(to_entity, rule.convert_to_stat, to_amount, Enums.StatType.CURRENT)
	else:  # STATUS
		var to_entity = _get_target_entity(rule.convert_to_party, source_entity)
		status_handler.apply_status(to_entity, rule.convert_to_status, to_amount)
	
	# Log the conversion
	var from_name = ""
	var to_name = ""
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		from_name = Enums.get_stat_string(rule.convert_from_stat)
	else:
		from_name = Enums.get_status_string(rule.convert_from_status)
	
	if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
		to_name = Enums.get_stat_string(rule.convert_to_stat)
	else:
		to_name = Enums.get_status_string(rule.convert_to_status)
	
	combat_manager.add_to_combat_log_string("    🔄 Converted %d %s → %d %s" % [from_amount, from_name, to_amount, to_name], Color.CYAN)

func _execute_meta_trigger(rule: ItemRule, source_entity):
	# Execute a meta-trigger (TRIGGER_OTHER_ITEMS).
	
	# This triggers all items of a certain trigger type on a target entity.
	# Includes recursion protection.

	# Check recursion depth
	if current_recursion_depth >= MAX_RECURSION_DEPTH:
		combat_manager.add_to_combat_log_string("    ⚠ Meta-trigger recursion limit reached", Color.ORANGE)
		return
	
	current_recursion_depth += 1
	
	# Get target entity
	var target_entity = _get_target_entity(rule.retrigger_target, source_entity)
	
	combat_manager.add_to_combat_log_string("    🔗 Meta-trigger: Activating %s's %s items" % [_get_entity_name(target_entity), Enums.get_trigger_type_string(rule.retrigger_type)], Color.LIGHT_BLUE)
	
	# Process items through CombatManager (which uses ItemProcessor)
	await combat_manager.process_entity_items_sequentially(target_entity, rule.retrigger_type)
	
	current_recursion_depth -= 1

# ===== DYNAMIC VALUE CALCULATION =====

func _calculate_effect_amount(rule: ItemRule, source_entity, target_entity) -> int:
	# Calculate the effect amount dynamically.
	
	# Can be:
	# - Fixed value (effect_of = VALUE)
	# - Based on a stat (effect_of = STAT_VALUE)
	# - Based on a status (effect_of = STATUS_VALUE)
	
	# Applies percentage modifiers if applicable.

	var base_amount = 0
	
	match rule.effect_of:
		ItemRule.ConditionValueType.VALUE:
			# Simple fixed value
			base_amount = rule.effect_amount
		
		ItemRule.ConditionValueType.STAT_VALUE:
			# Read from a stat
			var stat_entity = _get_target_entity(rule.effect_stat_party, source_entity)
			base_amount = stat_handler.get_stat_value(stat_entity, rule.effect_stat_value, rule.effect_stat_type)
		
		ItemRule.ConditionValueType.STATUS_VALUE:
			# Read from a status
			var status_entity = _get_target_entity(rule.effect_stat_party, source_entity)
			base_amount = status_handler.get_status_value(status_entity, rule.effect_status_value)
	
	# TODO: Apply percentage modifiers if needed (future feature)
	# if rule.has_percentage_modifier:
	#     base_amount = int(base_amount * rule.percentage_value)
	
	return base_amount

func _calculate_conversion_amount(rule: ItemRule, source_entity) -> int:
	# Calculate how much to convert based on conversion_amount_type.
	
	# Types:
	# - FIXED_VALUE: Convert a fixed amount
	# - PERCENTAGE: Convert a percentage of the current value
	# - ALL: Convert all available

	var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
	
	# Get current amount of source resource
	var current_amount = 0
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		current_amount = stat_handler.get_stat_value(from_entity, rule.convert_from_stat, Enums.StatType.CURRENT)
	else:  # STATUS
		current_amount = status_handler.get_status_value(from_entity, rule.convert_from_status)
	
	# Calculate based on type
	match rule.conversion_amount_type:
		ItemRule.ConversionAmountType.FIXED_VALUE:
			return mini(rule.conversion_amount_value, current_amount)
		
		ItemRule.ConversionAmountType.HALF:
			return int(current_amount * 0.5)
		
		ItemRule.ConversionAmountType.ALL:
			return current_amount
	
	return 0

func _validate_conversion_source(rule: ItemRule, source_entity, amount: int) -> bool:
	"""Validate that the source has enough to convert."""
	var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
	
	var current_amount = 0
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		current_amount = stat_handler.get_stat_value(from_entity, rule.convert_from_stat, Enums.StatType.CURRENT)
	else:  # STATUS
		current_amount = status_handler.get_status_value(from_entity, rule.convert_from_status)
	
	return current_amount >= amount

# ===== TARGET RESOLUTION =====

func _get_target_entity(target_type: Enums.TargetType, source_entity):
	# Get the target entity based on target type.
	
	# - SELF: The entity that owns the item
	# - ENEMY: The opposite entity
	# - BOTH: Not yet implemented (would need to return array)
	# - RANDOM: Randomly pick one

	match target_type:
		Enums.TargetType.SELF:
			return source_entity
		
		Enums.TargetType.ENEMY:
			if source_entity == combat_manager.player_entity:
				return combat_manager.enemy_entity
			else:
				return combat_manager.player_entity
		
		Enums.TargetType.BOTH:
			# TODO: Implement for effects that target both
			# For now, default to self
			return source_entity
		
		Enums.TargetType.RANDOM:
			# Randomly pick player or enemy
			if randf() > 0.5:
				return combat_manager.player_entity
			else:
				return combat_manager.enemy_entity
	
	return source_entity

# ===== HELPER FUNCTIONS =====

func _get_entity_name(entity) -> String:
	"""Get the display name of an entity."""
	if entity == combat_manager.player_entity:
		return "Player"
	elif entity == combat_manager.enemy_entity:
		if entity is Enemy:
			return entity.enemy_name
		return "Enemy"
	return "Unknown"

func reset_recursion_depth():
	# Reset recursion depth counter. Called at combat start.
	current_recursion_depth = 0
