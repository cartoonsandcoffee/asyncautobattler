class_name CombatEffectExecutor
extends Node

## Executes ItemRule effects
## Handles dynamic values, conversions, meta-triggers, and all effect types
signal non_weapon_damage_triggered(entity, amount: int, source_item: Item)

var combat_manager
var stat_handler: CombatStatHandler
var status_handler: CombatStatusHandler
var condition_evaluator: CombatConditionEvaluator
var damage_system: CombatDamageSystem

# Recursion protection for meta-triggers
const MAX_RECURSION_DEPTH = 3
var current_recursion_depth = 0

func _init(manager, stat_handler_ref: CombatStatHandler, status_handler_ref: CombatStatusHandler, condition_eval: CombatConditionEvaluator, damage_sys: CombatDamageSystem):
	combat_manager = manager
	stat_handler = stat_handler_ref
	status_handler = status_handler_ref
	condition_evaluator = condition_eval
	damage_system = damage_sys

# ===== MAIN ENTRY POINT =====

func execute_item_rule(item: Item, rule: ItemRule, source_entity, target_entity, _amount: int = 0):
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
	var condition_passes: bool = condition_evaluator.evaluate_condition(rule, source_entity, target_entity)
	if not condition_passes:
		var item_name = item.item_name if item else "Unknown Item"
		combat_manager.add_to_combat_log_string("   %s - %s" % [
			CombatLog.color_item(item_name, item),
			CombatLog.color(("Condition not met (skipped): " + condition_evaluator.condition_to_string(rule)), Color.GRAY)
		])
		return false  # Condition failed - signal to stop processing this item's rules

	# Calculate how many times to execute
	var execution_count = _calculate_execution_count(item, rule, source_entity)
	
	# Execute the effect (possibly multiple times)
	for i in range(execution_count):
		# Safeguard against triggering after combat is over
		if not combat_manager.combat_active and not combat_manager.is_processing_on_kill():
			return true

		# -- EXECUTE THE EFFECT!
		await _execute_effect_once(item, rule, source_entity, target_entity, _amount)

		# check to see if that one execute killed enemy
		if not combat_manager.combat_active and not combat_manager.is_processing_on_kill():
			return true

		# Small delay between repeats
		if i < execution_count - 1:
			await CombatSpeed.create_timer(CombatSpeed.get_duration("attack_gap"))
	
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
	
	# Check for persistent rules that might increase the repeats
	count += _check_persistent_repeat_modifiers(source_entity, item)

	return maxi(count, 1)  # At least 1

func _check_persistent_repeat_modifiers(entity, source_item):
	var count: int = 0

	# Get entity's inventory
	var inventory = null
	if entity == combat_manager.player_entity:
		inventory = Player.inventory
	elif "inventory" in entity:
		inventory = entity.inventory
	
	if not inventory:
		return 0
	
	# Collect items
	var all_items = []
	if inventory.weapon_slot:
		all_items.append(inventory.weapon_slot)
	for item in inventory.item_slots:
		if item:
			all_items.append(item)
	
	# Process persistent rules
	for item in all_items:
		for rule in item.rules:
			# Only check persistent rules
			if rule.trigger_type != Enums.TriggerType.PERSISTENT:
				continue
			
			# Only check if they modify the repeats value
			if rule.effect_type not in [Enums.EffectType.ADD_REPEATS]:
				continue
			
			# Evaluate condition
			if rule.has_condition:
				if not condition_evaluator.evaluate_condition(rule, entity, entity):
					continue
			
			# make sure the source item's category matches
			if !source_item.has_category(rule.target_item_category):
				continue

			# Apply effect
			count += rule.effect_amount
	
	return count

# ===== EFFECT EXECUTION =====

func _execute_effect_once(item: Item, rule: ItemRule, source_entity, target_entity, _trigger_amount: int = 0):
	# Execute a single instance of the effect.
	var item_name = item.item_name if item else "Unknown Item"

	# Determine the actual target entity based on rule.target_type
	var actual_target = _get_target_entity(rule.target_type, source_entity)
	
	# Execute based on effect type
	match rule.effect_type:
		Enums.EffectType.MODIFY_STAT:
			await _execute_modify_stat(rule, source_entity, actual_target, item, _trigger_amount)
		
		Enums.EffectType.APPLY_STATUS:
			await _execute_apply_status(rule, source_entity, actual_target, item, _trigger_amount)
		
		Enums.EffectType.REMOVE_STATUS:
			await _execute_remove_status(rule, source_entity, actual_target, item, _trigger_amount)
		
		Enums.EffectType.DEAL_DAMAGE:
			await _execute_deal_damage(rule, source_entity, actual_target, item, _trigger_amount)
			non_weapon_damage_triggered.emit(source_entity, _trigger_amount, item)
		
		Enums.EffectType.HEAL:
			await _execute_heal(rule, source_entity, actual_target, item, _trigger_amount)
		
		Enums.EffectType.CONVERT:
			await _execute_conversion(rule, source_entity, item)
		
		Enums.EffectType.TRIGGER_OTHER_ITEMS:
			await _execute_meta_trigger(rule, source_entity, item)

# ===== INDIVIDUAL EFFECT TYPES =====

func _execute_modify_stat(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	# Execute a MODIFY_STAT effect.
	# Routes to different handlers based on stat type:
	# - Currency stats (HP/Shield/Agility): Modified directly
	# - Output stats (Damage/Strikes/Burn): Modified via temp modifiers, then recalculated
	

	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	
	var read_type = rule.target_stat_type if rule.target_stat_type == Enums.StatType.BASE else Enums.StatType.CURRENT
	var old_value:int = stat_handler.get_stat_value(target_entity, rule.target_stat, read_type)

	# - SPAWN THE VISUAL INDICATOR
	if not CombatSpeed.is_instant_mode():
		await combat_manager.proc_item(item, rule, target_entity, amount)
	
	# Route based on stat type
	match rule.target_stat:
		# CURRENCY STATS: Modify directly via stat_handler
		Enums.Stats.HITPOINTS, Enums.Stats.SHIELD, Enums.Stats.AGILITY, Enums.Stats.BURN_DAMAGE, Enums.Stats.GOLD, Enums.Stats.STRIKES:
			stat_handler.change_stat(target_entity, rule.target_stat, amount, rule.target_stat_type, item)
		
		# OUTPUT STATS: Modify temp modifiers, then recalculate
		Enums.Stats.DAMAGE:
			target_entity.stats.modify_combat_temp_stat(Enums.Stats.DAMAGE, amount)
			stat_handler.recalculate_damage(target_entity)
		

	## -- JDM: Commenting this out to try match statement above for temp stat bonuses handling
	# Apply to stat handler
	#stat_handler.change_stat(target_entity, rule.target_stat, amount, rule.target_stat_type, item)
	# Note: stat_handler.change_stat() will emit signals and trigger items automatically

	var new_value:int = stat_handler.get_stat_value(target_entity, rule.target_stat, read_type)

	var verb:String = ""
	var effective_amount: int = 0

	if (amount > 0):
		verb = "gains"
		effective_amount = new_value - old_value
	else:
		verb = "loses"
		effective_amount = new_value - old_value
	
	#combat_manager.proc_item(item, rule, target_entity, effective_amount)

	var max_prefix: String = "Max " if rule.target_stat_type == Enums.StatType.BASE else ""

	combat_manager.add_to_combat_log_string("   %s - %s %s %s %s%s (%d → %d)" % [
		combat_manager.color_item(item.item_name, item),
		combat_manager.color_entity(combat_manager.get_entity_name(target_entity)),
		verb,
		combat_manager.color_text(str(abs(effective_amount)), Color.WHITE),
		max_prefix,
		CombatLog.color_stat(rule.target_stat),
		old_value, new_value
	])


func _execute_apply_status(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount:int = 0):
	"""Apply a status effect."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	var revert_to_random: bool = false

	# Handle RANDOM status
	var status_to_apply = rule.target_status
	if status_to_apply == Enums.StatusEffects.RANDOM:
		# Pick a random status (excluding NONE and RANDOM itself)
		var valid_statuses = []
		for status_value in Enums.StatusEffects.values():
			var status: Enums.StatusEffects = status_value
			if status not in [Enums.StatusEffects.NONE, Enums.StatusEffects.RANDOM, Enums.StatusEffects.ANY, Enums.StatusEffects.ALL]:
				valid_statuses.append(status)
		
		if valid_statuses.is_empty():
			return
		
		status_to_apply = valid_statuses[randi() % valid_statuses.size()]
		revert_to_random = true

	# Set the status for RANDOM for visual
	rule.target_status = status_to_apply

	# Queue visuals in correct order
	var combat_panel = combat_manager.get_tree().get_first_node_in_group("combat_panel")
	if not CombatSpeed.is_instant_mode():
		if combat_panel:
			combat_panel.spawn_item_proc_indicator(item, rule, source_entity, amount)

	#JDM: Revert back to random status when necessary for tooltip
	if revert_to_random:
		rule.target_status = Enums.StatusEffects.RANDOM
		
	# Apply through status handler
	status_handler.apply_status(target_entity, status_to_apply, amount, false, item)  # JDM: The last paramater "log_gain" is passed as false here so that it doesnt add status gains from items twice to the combat_log

	var new_stacks = status_handler.get_status_value(target_entity, status_to_apply)

	# LOG with colors — note: apply_status also logs gain; this adds the item source context
	combat_manager.add_to_combat_log_string("   %s - %s gains %s %s (total: %d)" % [
			CombatLog.color_item(item.item_name, item),
			CombatLog.color_entity(combat_manager.get_entity_name(target_entity)),
			CombatLog.color(str(amount), Color.WHITE),
			CombatLog.color_status(status_to_apply),
			new_stacks])

func _execute_remove_status(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	"""Remove a status effect."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	var revert_to_random: bool = false

	var status_to_remove = rule.target_status
	if status_to_remove == Enums.StatusEffects.RANDOM:
		# Get all active statuses on target
		var active_statuses = []
		for status_value in Enums.StatusEffects.values():
			var status: Enums.StatusEffects = status_value
			if status not in [Enums.StatusEffects.NONE, Enums.StatusEffects.RANDOM, Enums.StatusEffects.ANY, Enums.StatusEffects.ALL]:
				var stacks = status_handler.get_status_value(target_entity, status)
				if stacks > 0:
					active_statuses.append(status)
		
		if active_statuses.is_empty():
			# No active statuses to remove
			combat_manager.add_to_combat_log_string("   %s - %s" % [
				CombatLog.color_item(item.item_name, item),
				CombatLog.color("No statuses to remove", Color.GRAY)])
			return
		
		status_to_remove = active_statuses[randi() % active_statuses.size()]
		revert_to_random = true

	var old_stacks: int = status_handler.get_status_value(target_entity, status_to_remove)
	# check if there are stacks to remove
	if old_stacks <= 0:
		# No stacks to remove, skip visual and execution
		return

	var effective_amount: int = max(old_stacks - old_stacks, old_stacks - amount) #old_stacks - new_stacks

	# Overwrite the rule status for RANDOM for visual proc
	rule.target_status = status_to_remove

	# Queue visuals in correct order
	var combat_panel = combat_manager.get_tree().get_first_node_in_group("combat_panel")
	if not CombatSpeed.is_instant_mode():
		if combat_panel:
			combat_panel.spawn_item_proc_indicator(item, rule, target_entity, (amount * -1))  # JDM: Used to be 'effective_amount' but that looked wrong.

	# JDM: Revert rule back to random for rule text
	if revert_to_random:
		rule.target_status = Enums.StatusEffects.RANDOM

	# Remove through status handler
	status_handler.remove_status(target_entity, status_to_remove, amount)

	var new_stacks: int = status_handler.get_status_value(target_entity, status_to_remove)

	# LOG with colors
	combat_manager.add_to_combat_log_string("   %s - %s loses %s %s (remaining: %d)" % [
			CombatLog.color_item(item.item_name, item),
			CombatLog.color_entity(combat_manager.get_entity_name(target_entity)),
			CombatLog.color(str(amount), Color.WHITE),
			CombatLog.color_status(status_to_remove),
			new_stacks
		])

func _execute_deal_damage(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	"""Deal direct damage."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	
	# LOG before damage
	combat_manager.add_to_combat_log_string("   %s - %s takes %s damage" % [
			CombatLog.color_item(item.item_name, item),
			CombatLog.color_entity(combat_manager.get_entity_name(target_entity)),
			CombatLog.color(str(amount), Color.RED)
		])

	# VISUAL INDICATOR SPAWNED THROUGH DAMAGE SYSTEM

	# Deal damage through damage system
	await damage_system.apply_damage(target_entity, amount, item, "item")

func _execute_heal(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	"""Heal HP."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	var old_hp = target_entity.stats.hit_points_current
	var max_hp = target_entity.stats.hit_points

	# Heal through damage system
	await damage_system.heal_entity(target_entity, amount, item)

	var new_hp = target_entity.stats.hit_points_current
	var actual_heal = new_hp - old_hp
	var overheal = amount - actual_heal  # Amount that was wasted above max HP

	# LOG with colors
	if actual_heal > 0:
		# SPAWN VISUAL INDICATOR
		if not CombatSpeed.is_instant_mode():
			await combat_manager.proc_item(item, rule, target_entity, actual_heal)
		combat_manager.add_to_combat_log_string("   %s - %s" % [
				CombatLog.color_item(item.item_name, item),
				CombatLog.fmt_heal(combat_manager.get_entity_name(target_entity), actual_heal, old_hp, new_hp)
			])
	else:
		combat_manager.add_to_combat_log_string("   %s - %s already at full HP" % [
				CombatLog.color_item(item.item_name, item),
				CombatLog.color_entity(combat_manager.get_entity_name(target_entity))
			])

	if overheal > 0:
		combat_manager.add_to_combat_log_string(CombatLog.fmt_overheal(combat_manager.get_entity_name(target_entity), overheal))
		status_handler.overheal_triggered.emit(target_entity, overheal)

func _execute_conversion(rule: ItemRule, source_entity, item: Item):
	# Execute a CONVERT effect.
	
	# Conversions are atomic operations that convert one resource to another.
	# IMPORTANT: If the entity doesn't have enough source resource, conversion FAILS.
	
	# Examples:
	# - Convert 1 armor to 1 attack
	# - Convert 50% of poison stacks to damage
	# - Convert all thorns to regen

	# Determine FROM amount
	var from_amount = _calculate_conversion_amount(rule, source_entity)
	var from_name: String = ""
	var to_name:String = ""

	# GET TO/FROM NAMES
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		from_name = CombatLog.color_stat_str(Enums.get_stat_string(rule.convert_from_stat))
	else:
		from_name = CombatLog.color_status_str(Enums.get_status_string(rule.convert_from_status))
	
	if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
		to_name = CombatLog.color_stat_str(Enums.get_stat_string(rule.convert_to_stat))
	else:
		to_name = CombatLog.color_status_str(Enums.get_status_string(rule.convert_to_status))

	# Validate we have enough source resource
	# If we DON'T display the appropriate message
	if from_amount <= 0:
		combat_manager.add_to_combat_log_string("   %s - Conversion failed: no %s to convert." % [
			combat_manager.color_item(item.item_name, item),
			from_name
		])
		return

	if not _validate_conversion_source(rule, source_entity, from_amount):
		combat_manager.add_to_combat_log_string("   %s - %s %s %s" % [
				CombatLog.color_item(item.item_name, item),
				CombatLog.color("Conversion failed: Not enough", Color.GRAY),
				from_name,
				CombatLog.color("(need %d)" % from_amount, Color.GRAY)])
		return
	
	var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
	var to_entity = _get_target_entity(rule.convert_to_party, source_entity)
	var to_amount = int(from_amount * rule.conversion_ratio) 	# Calculate TO amount (apply conversion ratio)

	combat_manager.add_to_combat_log_string("   %s - %s's %s %s converted to %s %s for %s" % [
		combat_manager.color_item(item.item_name, item),
		combat_manager.color_entity(combat_manager.get_entity_name(from_entity)),
		combat_manager.color_text(str(from_amount), Color.WHITE),
		from_name,
		combat_manager.color_text(str(to_amount), Color.WHITE),
		to_name,
		combat_manager.color_entity(combat_manager.get_entity_name(to_entity))
	])

	# Remove FROM resource
	var visual_rule_placeholder:ItemRule = ItemRule.new()
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		stat_handler.change_stat(from_entity, rule.convert_from_stat, -from_amount, Enums.StatType.CURRENT, item)
		visual_rule_placeholder.effect_type = Enums.EffectType.MODIFY_STAT
		visual_rule_placeholder.target_type = rule.convert_from_party
		visual_rule_placeholder.target_stat_type = Enums.StatType.CURRENT
		visual_rule_placeholder.target_stat = rule.convert_from_stat
		visual_rule_placeholder.effect_of = ItemRule.ConditionValueType.VALUE
		visual_rule_placeholder.effect_amount = -from_amount
		visual_rule_placeholder.trigger_type = rule.trigger_type
	else:  # STATUS
		status_handler.remove_status(from_entity, rule.convert_from_status, from_amount)
		visual_rule_placeholder.effect_type = Enums.EffectType.REMOVE_STATUS
		visual_rule_placeholder.target_type = rule.convert_from_party
		visual_rule_placeholder.target_status = rule.convert_from_status
		visual_rule_placeholder.effect_of = ItemRule.ConditionValueType.VALUE
		visual_rule_placeholder.effect_amount = from_amount
		visual_rule_placeholder.trigger_type = rule.trigger_type

	# SPAWN PROC VISUAL FOR CONVERT_FROM PART
	if not CombatSpeed.is_instant_mode():
		combat_manager.proc_item(item, visual_rule_placeholder, source_entity, -from_amount)


	# Add TO resource
	var visual_rule_placeholder_to = ItemRule.new()
	if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
		stat_handler.change_stat(to_entity, rule.convert_to_stat, to_amount, Enums.StatType.CURRENT, item)
		visual_rule_placeholder_to.effect_type = Enums.EffectType.MODIFY_STAT
		visual_rule_placeholder_to.target_type = rule.convert_to_party
		visual_rule_placeholder_to.target_stat_type = Enums.StatType.CURRENT
		visual_rule_placeholder_to.target_stat = rule.convert_to_stat
		visual_rule_placeholder_to.effect_of = ItemRule.ConditionValueType.VALUE
		visual_rule_placeholder_to.effect_amount = to_amount
		visual_rule_placeholder_to.trigger_type = rule.trigger_type		
	else:  # STATUS
		status_handler.apply_status(to_entity, rule.convert_to_status, to_amount, true, item)
		visual_rule_placeholder_to.effect_type = Enums.EffectType.APPLY_STATUS
		visual_rule_placeholder_to.target_type = rule.convert_to_party
		visual_rule_placeholder_to.target_status = rule.convert_to_status
		visual_rule_placeholder_to.effect_of = ItemRule.ConditionValueType.VALUE
		visual_rule_placeholder_to.effect_amount = to_amount
		visual_rule_placeholder_to.trigger_type = rule.trigger_type		

	# SPAWN PROC VISUAL FOR CONVERT_TO PART
	if not CombatSpeed.is_instant_mode():
		combat_manager.proc_item(item, visual_rule_placeholder_to, source_entity, to_amount)

func _execute_meta_trigger(rule: ItemRule, source_entity, item: Item):
	# Execute a meta-trigger (TRIGGER_OTHER_ITEMS).
	
	# This triggers all items of a certain trigger type on a target entity.
	# Includes recursion protection.

	# Check recursion depth
	if current_recursion_depth >= MAX_RECURSION_DEPTH:
		combat_manager.add_to_combat_log_string(CombatLog.fmt_recursion_limit())
		return
	
	current_recursion_depth += 1
	
	var target_entity = _get_target_entity(rule.retrigger_target, source_entity)
	
	combat_manager.add_to_combat_log_string("     Meta-trigger: Activating %s's %s items [%s]" % [
		CombatLog.color_entity(_get_entity_name(target_entity)),
		CombatLog.color(Enums.get_trigger_type_string(rule.retrigger_type), Color.LIGHT_BLUE),
		CombatLog.color(Enums.get_item_to_retrigger_string(rule.retrigger_item), Color.LIGHT_BLUE)])
	
	var candidates: Array = _get_retrigger_candidates(target_entity, rule)
	
	for item_data in candidates:
		for r in item_data.item.rules:
			if r.trigger_type == rule.retrigger_type:
				await execute_item_rule(item_data.item, r, target_entity, target_entity)
	
	current_recursion_depth -= 1


func _get_retrigger_candidates(entity, rule: ItemRule) -> Array:
	var all_matching: Array = combat_manager.item_processor.collect_triggered_items(entity, rule.retrigger_type)
	
	var seen: Array = []
	var unique_items: Array = []
	for item_data in all_matching:
		if item_data.item not in seen:
			# Apply category filter if specified
			if rule.retrigger_category != "" and not item_data.item.has_category(rule.retrigger_category):
				continue
			seen.append(item_data.item)
			unique_items.append(item_data)
	
	match rule.retrigger_item:
		Enums.ItemToRetrigger.NONE, Enums.ItemToRetrigger.ALL:
			return unique_items
		Enums.ItemToRetrigger.RANDOM:
			if unique_items.is_empty(): return []
			return [unique_items[randi() % unique_items.size()]]
		Enums.ItemToRetrigger.FIRST:
			if unique_items.is_empty(): return []
			return [unique_items[0]]
		Enums.ItemToRetrigger.LAST:
			if unique_items.is_empty(): return []
			return [unique_items[unique_items.size() - 1]]
	
	return unique_items

# ===== DYNAMIC VALUE CALCULATION =====

func _calculate_effect_amount(rule: ItemRule, source_entity, target_entity, _trigger_amount: int = 0) -> int:
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
	
		ItemRule.ConditionValueType.TRIGGER_AMOUNT:
			# Read from the amount of the previous item that caused this effect to trigger
			base_amount = _trigger_amount

	# TODO: Apply percentage modifiers if needed (future feature)
	# if rule.has_percentage_modifier:
	var multiplier: float = 1.0
	if rule.effect_multiplier > 0.0:
		multiplier = rule.effect_multiplier

	base_amount = int(base_amount * multiplier)
	
	return base_amount

func _calculate_conversion_amount(rule: ItemRule, source_entity) -> int:
	# Calculate how much to convert based on conversion_amount_type.
	
	# Types:
	# - FIXED_VALUE: Convert a fixed amount
	# - PERCENTAGE: Convert a percentage of the current value
	# - ALL: Convert all available

	var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
	
	# Get current amount of source resource
	var current_amount:int = 0
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
