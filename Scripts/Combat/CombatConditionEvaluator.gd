class_name CombatConditionEvaluator
extends Node

## Evaluates ItemRule conditions
## Determines if a rule's condition is met before executing its effect

var combat_manager
var stat_handler: CombatStatHandler
var status_handler: CombatStatusHandler

func _init(manager, stat_handler_ref: CombatStatHandler, status_handler_ref: CombatStatusHandler):
	combat_manager = manager
	stat_handler = stat_handler_ref
	status_handler = status_handler_ref

# ===== MAIN ENTRY POINT =====

func evaluate_condition(rule: ItemRule, source_entity, target_entity) -> bool:
	# Evaluate if a rule's condition is met.
	
	# Returns true if:
	# - Rule has no condition (has_condition = false)
	# - Rule's condition evaluates to true
	
	# Returns false if condition fails.

	# No condition means always pass
	if not rule.has_condition:
		return true
	
	# Get the entity to check the condition on
	var check_entity = get_condition_check_entity(rule, source_entity, target_entity)
	
	if not check_entity:
		return false
	
	# Evaluate based on condition type (STAT or STATUS)
	if rule.condition_type == ItemRule.StatOrStatus.STAT:
		return _evaluate_stat_condition(rule, check_entity)
	elif rule.condition_type == ItemRule.StatOrStatus.STATUS:
		return _evaluate_status_condition(rule, check_entity)
	
	return false

# ===== STAT CONDITIONS =====

func _evaluate_stat_condition(rule: ItemRule, entity) -> bool:
	# Evaluate a stat-based condition.
	
	# Examples:
	# - "If your current HP > 10"
	# - "If enemy's missing HP >= 50"
	# - "If your shield < enemy's damage"

	# Get the stat value to check
	var stat_value = stat_handler.get_stat_value(entity, rule.condition_stat, Enums.StatType.CURRENT)
	
	# Get the comparison value
	var compare_value = _get_comparison_value(rule, entity)
	
	# Perform the comparison
	return _compare_values(stat_value, compare_value, rule.condition_comparison)

# ===== STATUS CONDITIONS =====

func _evaluate_status_condition(rule: ItemRule, entity) -> bool:
	# Evaluate a status-based condition.
	
	# Examples:
	# - "If you have poison > 0"
	# - "If enemy has thorns >= 5"

	# Get the status value to check
	var status_value = status_handler.get_status_value(entity, rule.condition_status)
	
	# Get the comparison value
	var compare_value = _get_comparison_value(rule, entity)
	
	# Perform the comparison
	return _compare_values(status_value, compare_value, rule.condition_comparison)

# ===== COMPARISON VALUE RESOLUTION =====

func _get_comparison_value(rule: ItemRule, checking_entity) -> int:
	# Get the value to compare against.
	
	# Can be:
	# - A fixed value (compare_to = VALUE)
	# - Another entity's stat (compare_to = STAT_VALUE)
	# - Another entity's status (compare_to = STATUS_VALUE)

	match rule.compare_to:
		ItemRule.ConditionValueType.VALUE:
			# Simple fixed value
			return rule.condition_value
		
		ItemRule.ConditionValueType.STAT_VALUE:
			# Compare to another entity's stat
			var compare_entity = get_target_entity_for_condition(rule.condition_party, checking_entity)
			if compare_entity:
				return stat_handler.get_stat_value(compare_entity, rule.condition_party_stat, rule.condition_stat_type)
			return 0
		
		ItemRule.ConditionValueType.STATUS_VALUE:
			# Compare to another entity's status
			var compare_entity = get_target_entity_for_condition(rule.condition_party, checking_entity)
			if compare_entity:
				return status_handler.get_status_value(compare_entity, rule.condition_party_status)
			return 0
	
	return 0

# ===== COMPARISON OPERATIONS =====

func _compare_values(left_value: int, right_value: int, operator: String) -> bool:
	# Perform comparison using the operator string.
	
	# Supported operators: >, <, >=, <=, ==, !=

	match operator:
		">":
			return left_value > right_value
		"<":
			return left_value < right_value
		">=":
			return left_value >= right_value
		"<=":
			return left_value <= right_value
		"==":
			return left_value == right_value
		"!=":
			return left_value != right_value
	
	# Default to false for unknown operators
	return false

# ===== ENTITY RESOLUTION =====

func get_condition_check_entity(rule: ItemRule, source_entity, target_entity):
	# Determine which entity to check the condition on.
	
	# This is separate from get_target_entity_for_condition because:
	# - condition_check_entity: The entity whose stat/status we're checking
	# - condition_party: The entity we're comparing AGAINST (for STAT_VALUE/STATUS_VALUE)

	# For now, conditions are always checked on the source entity
	# (the entity that owns the item)
	return source_entity

func get_target_entity_for_condition(target_type: Enums.TargetType, source_entity):
	# Get the entity referenced by a target type for condition comparisons.
	
	# Examples:
	# - SELF: The entity that owns the item
	# - ENEMY: The opposite entity

	match target_type:
		Enums.TargetType.SELF:
			return source_entity
		
		Enums.TargetType.ENEMY:
			# Return the opposite entity
			if source_entity == combat_manager.player_entity:
				return combat_manager.enemy_entity
			else:
				return combat_manager.player_entity
		
		Enums.TargetType.BOTH:
			# Can't compare to both - return source
			return source_entity
		
		Enums.TargetType.RANDOM:
			# For conditions, random doesn't make sense - return source
			return source_entity
	
	return source_entity

# ===== UTILITY FUNCTIONS =====

func condition_to_string(rule: ItemRule) -> String:
	# Convert a condition to a readable string for debugging.
	# Used by CombatManager for logging.

	if not rule.has_condition:
		return "No condition"
	
	var condition_str = "If "
	
	# Add the stat/status being checked
	if rule.condition_type == ItemRule.StatOrStatus.STAT:
		condition_str += Enums.get_stat_string(rule.condition_stat)
	else:
		condition_str += Enums.get_status_string(rule.condition_status)
	
	# Add the operator
	condition_str += " " + rule.condition_comparison + " "
	
	# Add the comparison value
	match rule.compare_to:
		ItemRule.ConditionValueType.VALUE:
			condition_str += str(rule.condition_value)
		ItemRule.ConditionValueType.STAT_VALUE:
			condition_str += Enums.get_target_string(rule.condition_party) + " "
			condition_str += Enums.get_stat_type_string(rule.condition_stat_type) + " "
			condition_str += Enums.get_stat_string(rule.condition_party_stat)
		ItemRule.ConditionValueType.STATUS_VALUE:
			condition_str += Enums.get_target_string(rule.condition_party) + " "
			condition_str += Enums.get_status_string(rule.condition_party_status)
	
	return condition_str