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

func _init(manager, stat_handler_ref: CombatStatHandler, status_handler_ref: CombatStatusHandler, condition_eval: CombatConditionEvaluator, damage_sys: CombatDamageSystem):
	combat_manager = manager
	stat_handler = stat_handler_ref
	status_handler = status_handler_ref
	condition_evaluator = condition_eval
	damage_system = damage_sys

# ===== MAIN ENTRY POINT =====

func execute_item_rule(item: Item, rule: ItemRule, source_entity, target_entity, _amount: int = 0, resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE, override_execution_count: int = -1):
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

	# if the status is RANDOM then pick which status so we can pass it consistently for visuals
	if rule.effect_type in [Enums.EffectType.APPLY_STATUS, Enums.EffectType.REMOVE_STATUS, Enums.EffectType.CONVERT]:
		resolved_status = resolve_random_status(rule, target_entity)

	# Check condition
	var condition_passes: bool = condition_evaluator.evaluate_condition(rule, source_entity, target_entity)
	if not condition_passes:
		var item_name = item.item_name if item else "Unknown Item"
		combat_manager.event_queue.enqueue(CombatEvent.log("   %s - %s" % [
			CombatLog.color_item(item_name, item),
			CombatLog.color(("Condition not met (skipped): " + condition_evaluator.condition_to_string(rule)), Color.GRAY)
		]))
		return false  # Condition failed - signal to stop processing this item's rules

	# Calculate how many times to execute
	var execution_count = override_execution_count if override_execution_count >= 1 else _calculate_execution_count(item, rule, source_entity)
	
	# Execute the effect (possibly multiple times)
	for i in range(execution_count):
		# Safeguard against triggering after combat is over
		if not combat_manager.combat_active:
			return true

		# -- EXECUTE THE EFFECT!
		_execute_effect_once(item, rule, source_entity, target_entity, _amount, resolved_status)

		# check to see if that one execute killed enemy
		if not combat_manager.combat_active:
			return true

		# Small delay between repeats
		#if i < execution_count - 1:
		#	combat_manager.event_queue.enqueue(CombatEvent.delay(CombatSpeed.get_duration("attack_gap")))
	
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

	var all_items = combat_manager.get_all_entity_items(entity)
	var opponent = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity

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
				if not condition_evaluator.evaluate_condition(rule, entity, opponent):
					continue
			
			# make sure the source item's category matches
			if !source_item.has_category(rule.target_item_category):
				continue

			# Apply effect
			count += rule.effect_amount
	
	return count

# ===== EFFECT EXECUTION =====

func _execute_effect_once(item: Item, rule: ItemRule, source_entity, target_entity, _trigger_amount: int = 0, resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE):
	# Execute a single instance of the effect.
	var item_name = item.item_name if item else "Unknown Item"

	# Determine the actual target entity based on rule.target_type
	var actual_target = _get_target_entity(rule.target_type, source_entity)
	
	# Execute based on effect type
	match rule.effect_type:
		Enums.EffectType.MODIFY_STAT:
			_execute_modify_stat(rule, source_entity, actual_target, item, _trigger_amount)
		
		Enums.EffectType.APPLY_STATUS:
			_execute_apply_status(rule, source_entity, actual_target, item, _trigger_amount, resolved_status)
		
		Enums.EffectType.REMOVE_STATUS:
			_execute_remove_status(rule, source_entity, actual_target, item, _trigger_amount, resolved_status)
		
		Enums.EffectType.DEAL_DAMAGE:
			_execute_deal_damage(rule, source_entity, actual_target, item, _trigger_amount)
			non_weapon_damage_triggered.emit(source_entity, _trigger_amount, item)
		
		Enums.EffectType.HEAL:
			_execute_heal(rule, source_entity, actual_target, item, _trigger_amount)
		
		Enums.EffectType.CONVERT:
			_execute_conversion(rule, source_entity, item)
		
		Enums.EffectType.TRIGGER_OTHER_ITEMS:
			await _execute_meta_trigger(rule, source_entity, item)

# ===== INDIVIDUAL EFFECT TYPES =====

func _execute_modify_stat(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	# Execute a MODIFY_STAT effect.
	# Routes to different handlers based on stat type:

	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)

	# Route based on stat type
	match rule.target_stat:
		# CURRENCY STATS: Modify directly via stat_handler
		Enums.Stats.HITPOINTS, Enums.Stats.SHIELD, Enums.Stats.AGILITY, Enums.Stats.BURN_DAMAGE, Enums.Stats.GOLD, Enums.Stats.STRIKES:
			combat_manager.event_queue.enqueue_next(CombatEvent.modify_stat(target_entity, rule.target_stat, amount, rule.target_stat_type, item))
		
		# DAMAGE stat: modify temp modifier and recalculate immediately.
		# Intentionally synchronous — recalculate_damage is not a player-visible event,
		# it must complete before any subsequent stat reads in this execution context.
		# LOG enqueued here since MODIFY_STAT is not enqueued for DAMAGE.		
		Enums.Stats.DAMAGE:
			var old_value: int = stat_handler.get_stat_value(target_entity, rule.target_stat, Enums.StatType.CURRENT)
			target_entity.stats.modify_combat_temp_stat(Enums.Stats.DAMAGE, amount)
			stat_handler.recalculate_damage(target_entity)
			var new_value: int = stat_handler.get_stat_value(target_entity, rule.target_stat, Enums.StatType.CURRENT)
			combat_manager.stat_changed.emit(target_entity, rule.target_stat, old_value, new_value)
			var max_prefix: String = "Max " if rule.target_stat_type == Enums.StatType.BASE else ""
			combat_manager.event_queue.enqueue(CombatEvent.log("   %s: %s %s %s %s%s (%d → %d)" % [
				combat_manager.color_item(item.item_name, item),
				combat_manager.color_entity(combat_manager.get_entity_name(target_entity)),
				"gains" if amount > 0 else "loses",
				combat_manager.color_text(str(abs(new_value - old_value)), Color.WHITE),
				max_prefix,
				CombatLog.color_stat(rule.target_stat),
				old_value, new_value
			]))

func _execute_apply_status(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount:int = 0, resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE):
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	combat_manager.event_queue.enqueue_next(CombatEvent.apply_status(target_entity, resolved_status, amount, item))

func _execute_remove_status(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0, resolved_status: Enums.StatusEffects = Enums.StatusEffects.NONE):
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	var old_stacks: int = status_handler.get_status_value(target_entity, resolved_status)
	if old_stacks <= 0:
		return
	combat_manager.event_queue.enqueue_next(CombatEvent.remove_status(target_entity, resolved_status, amount, item))


func _execute_deal_damage(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	"""Deal direct damage."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)

	# Deal damage through queue system
	combat_manager.event_queue.enqueue_next(CombatEvent.deal_damage(item, target_entity, amount, "item"))

	# LOG damage
	combat_manager.event_queue.enqueue_next(CombatEvent.log("   %s: %s takes %s damage" % [
		CombatLog.color_item(item.item_name, item),
		CombatLog.color_entity(combat_manager.get_entity_name(target_entity)),
		CombatLog.color(str(amount), Color.RED)
	]))


func _execute_heal(rule: ItemRule, source_entity, target_entity, item: Item, _trigger_amount: int = 0):
	"""Heal HP."""
	var amount = _calculate_effect_amount(rule, source_entity, target_entity, _trigger_amount)
	var old_hp = target_entity.stats.hit_points_current
	var max_hp = target_entity.stats.hit_points
	var new_hp = min(old_hp + amount, max_hp)  # preview
	var actual_heal = new_hp - old_hp
	var overheal = amount - actual_heal
	damage_system.heal_entity(target_entity, amount, item)

	if overheal > 0:
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
		combat_manager.event_queue.enqueue(CombatEvent.log("   %s - Conversion failed: no %s to convert." % [
			combat_manager.color_item(item.item_name, item),
			from_name
		]))
		return

	if not _validate_conversion_source(rule, source_entity, from_amount):
		combat_manager.event_queue.enqueue(CombatEvent.log("   %s: %s %s %s" % [
				CombatLog.color_item(item.item_name, item),
				CombatLog.color("Conversion failed: Not enough", Color.GRAY),
				from_name,
				CombatLog.color("(need %d)" % from_amount, Color.GRAY)]))
		return
	
	var from_entity = _get_target_entity(rule.convert_from_party, source_entity)
	var to_entity = _get_target_entity(rule.convert_to_party, source_entity)
	var to_amount = int(from_amount * rule.conversion_ratio) 	# Calculate TO amount (apply conversion ratio)

	var from_old: int = 0
	var from_new: int = 0
	var from_needs_threshold: bool = false
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		from_old = combat_manager.stat_handler.get_stat_value(from_entity, rule.convert_from_stat)
		from_new = max(0, from_old - from_amount)
		from_needs_threshold = rule.convert_from_stat in [Enums.Stats.HITPOINTS, Enums.Stats.SHIELD]

	# Insert TO resource (inserted first = lands last in sequence)
	if rule.convert_to_type == ItemRule.StatOrStatus.STAT:
		combat_manager.event_queue.enqueue_next(CombatEvent.modify_stat(to_entity, rule.convert_to_stat, to_amount, Enums.StatType.CURRENT, item))
	else:
		combat_manager.event_queue.enqueue_next(CombatEvent.apply_status(to_entity, rule.convert_to_status, to_amount, item))

	# Insert FROM resource + threshold check
	if rule.convert_from_type == ItemRule.StatOrStatus.STAT:
		if from_needs_threshold:
			combat_manager.event_queue.enqueue_next(CombatEvent.check_thresholds(from_entity, rule.convert_from_stat, from_old, from_new))
		combat_manager.event_queue.enqueue_next(CombatEvent.modify_stat(from_entity, rule.convert_from_stat, -from_amount, Enums.StatType.CURRENT, item))
	else:
		combat_manager.event_queue.enqueue_next(CombatEvent.remove_status(from_entity, rule.convert_from_status, from_amount))

	# Insert LOG last so it lands at front
	combat_manager.event_queue.enqueue_next(CombatEvent.log("   %s: %s's %s %s converted to %s %s for %s" % [
		combat_manager.color_item(item.item_name, item),
		combat_manager.color_entity(combat_manager.get_entity_name(from_entity)),
		combat_manager.color_text(str(from_amount), Color.WHITE),
		from_name,
		combat_manager.color_text(str(to_amount), Color.WHITE),
		to_name,
		combat_manager.color_entity(combat_manager.get_entity_name(to_entity))
	]))


func _execute_meta_trigger(rule: ItemRule, source_entity, item: Item):
	# Execute a meta-trigger (TRIGGER_OTHER_ITEMS).
	
	# This triggers all items of a certain trigger type on a target entity.
	# Includes recursion protection.

	var target_entity = _get_target_entity(rule.retrigger_target, source_entity)
	var candidates: Array = _get_retrigger_candidates(target_entity, rule, item)
	
	if candidates.is_empty():
		return
	
	# Build EXECUTE_RULE events for each candidate
	var events: Array[CombatEvent] = []
	for item_data in candidates:
		for r in item_data.item.rules:
			if r.trigger_type == rule.retrigger_type:
				events.append(CombatEvent.execute_rule(item_data.item, r, target_entity, r.trigger_type))

	# Spend trigger flag if configured and retrigger_item == ALL
	if rule.spend_trigger_flag and rule.retrigger_item == Enums.ItemToRetrigger.ALL:
		match rule.retrigger_type:
			Enums.TriggerType.EXPOSED:
				combat_manager.stat_handler._mark_exposed_triggered(target_entity, true)
			Enums.TriggerType.WOUNDED:
				combat_manager.stat_handler._mark_wounded_triggered(target_entity, true)

	# enqueue_batch_next first (items in order at front), then enqueue_next log
	# so log lands at front and processes before items
	combat_manager.event_queue.enqueue_batch_next(events)
	combat_manager.event_queue.enqueue_next(CombatEvent.log("     Meta-trigger: Activating %s's %s items [%s]" % [
		CombatLog.color_entity(_get_entity_name(target_entity)),
		CombatLog.color(Enums.get_trigger_type_string(rule.retrigger_type), Color.LIGHT_BLUE),
		CombatLog.color(Enums.get_item_to_retrigger_string(rule.retrigger_item), Color.LIGHT_BLUE)]))
	

func _get_retrigger_candidates(entity, rule: ItemRule, source_item: Item = null) -> Array:
	var all_matching: Array = combat_manager.item_processor.collect_triggered_items(entity, rule.retrigger_type)
	
	var seen: Array = []
	var unique_items: Array = []
	for item_data in all_matching:
		if item_data.item not in seen:
			# Exclude item that triggered the re-trigger
			if source_item and item_data.item == source_item:
				continue
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
	if rule.effect_multiplier != 0.0:
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

func resolve_random_status(rule: ItemRule, target_entity, override_status: Enums.StatusEffects = Enums.StatusEffects.NONE) -> Enums.StatusEffects:
	var status = override_status if override_status != Enums.StatusEffects.NONE else rule.target_status
	if status != Enums.StatusEffects.RANDOM:
		return status
	if rule.effect_type == Enums.EffectType.REMOVE_STATUS:
		var active = []
		for s in Enums.StatusEffects.values():
			if s not in [Enums.StatusEffects.NONE, Enums.StatusEffects.RANDOM, Enums.StatusEffects.ANY, Enums.StatusEffects.ALL]:
				if combat_manager.status_handler.get_status_value(target_entity, s) > 0:
					active.append(s)
		return active[randi() % active.size()] if not active.is_empty() else Enums.StatusEffects.NONE
	else:
		var valid = []
		for s in Enums.StatusEffects.values():
			if s not in [Enums.StatusEffects.NONE, Enums.StatusEffects.RANDOM, Enums.StatusEffects.ANY, Enums.StatusEffects.ALL]:
				valid.append(s)
		return valid[randi() % valid.size()] if not valid.is_empty() else Enums.StatusEffects.NONE
