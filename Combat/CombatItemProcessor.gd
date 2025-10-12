class_name CombatItemProcessor
extends Node

## Handles item trigger validation, occurrence counting, and item collection
## This is the gatekeeper that determines WHICH items should trigger and WHEN

# Reference to CombatManager for entity access
var combat_manager

# Occurrence tracking per entity per trigger type
# Structure: { entity: { trigger_type: { item: occurrence_count } } }
var occurrence_counters: Dictionary = {}

# Track items that have triggered once (for trigger_only_once)
# Structure: { entity: { item: has_triggered } }
var triggered_once_items: Dictionary = {}

func _init(manager):
	combat_manager = manager

# ===== MAIN ENTRY POINT =====

func process_items(entity, trigger_type: Enums.TriggerType, trigger_stat = Enums.Stats.NONE) -> Array:
	# Main entry point for processing items with a given trigger.
	# Returns an array of item data dictionaries ready for execution.

	# Collect all items that match this trigger
	var triggered_items = collect_triggered_items(entity, trigger_type, trigger_stat)
	
	# Filter based on trigger conditions and increment counters
	var validated_items = []
	for item_data in triggered_items:
		var item = item_data.item
		var rule = item_data.rule
		
		# Check if this item can trigger
		if can_item_trigger(entity, item, rule, trigger_type):
			# Increment occurrence counter
			increment_occurrence_counter(entity, item, trigger_type)
			
			# Check if occurrence number matches
			if check_occurrence_match(entity, item, rule, trigger_type):
				validated_items.append(item_data)
				
				# Mark as triggered if trigger_only_once
				if item.trigger_only_once:
					mark_item_as_triggered(entity, item)
	
	return validated_items

func process_items_with_status(entity, trigger_type: Enums.TriggerType, trigger_status: Enums.StatusEffects) -> Array:
	# Process items that trigger based on status effects.
	# Used for ON_STATUS_GAINED and ON_STATUS_REMOVED.

	var triggered_items = collect_triggered_items_with_status(entity, trigger_type, trigger_status)
	
	var validated_items = []
	for item_data in triggered_items:
		var item = item_data.item
		var rule = item_data.rule
		
		if can_item_trigger(entity, item, rule, trigger_type):
			increment_occurrence_counter(entity, item, trigger_type)
			
			if check_occurrence_match(entity, item, rule, trigger_type):
				validated_items.append(item_data)
				
				if item.trigger_only_once:
					mark_item_as_triggered(entity, item)
	
	return validated_items

# ===== ITEM COLLECTION =====

func collect_triggered_items(entity, trigger_type: Enums.TriggerType, trigger_stat = Enums.Stats.NONE) -> Array:
	# Collect all items/rules that match the given trigger type and optional stat.
	# Returns array of {item, rule, slot_index} dictionaries.

	var items_to_proc = []
	
	if entity == combat_manager.player_entity:
		# Check weapon first
		if entity.inventory.weapon_slot:
			for rule in entity.inventory.weapon_slot.rules:
				if rule.trigger_type == trigger_type:
					# If trigger has a stat filter, check it
					if trigger_stat != Enums.Stats.NONE and rule.trigger_stat != Enums.Stats.NONE:
						if rule.trigger_stat == trigger_stat:
							items_to_proc.append({
								"item": entity.inventory.weapon_slot,
								"rule": rule,
								"slot_index": -1  # -1 indicates weapon
							})
					else:
						# No stat filter, just add it
						items_to_proc.append({
							"item": entity.inventory.weapon_slot,
							"rule": rule,
							"slot_index": -1
						})
		
		# Then check inventory items in order
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				for rule in item.rules:
					if rule.trigger_type == trigger_type:
						# Check stat filter if applicable
						if trigger_stat != Enums.Stats.NONE and rule.trigger_stat != Enums.Stats.NONE:
							if rule.trigger_stat == trigger_stat:
								items_to_proc.append({
									"item": item,
									"rule": rule,
									"slot_index": i
								})
						else:
							items_to_proc.append({
								"item": item,
								"rule": rule,
								"slot_index": i
							})
	
	else:  # Enemy entity
		# Check enemy abilities
		for ability in entity.abilities:
			if ability:
				for rule in ability.rules:
					if rule.trigger_type == trigger_type:
						if trigger_stat != Enums.Stats.NONE and rule.trigger_stat != Enums.Stats.NONE:
							if rule.trigger_stat == trigger_stat:
								items_to_proc.append({
									"item": ability,
									"rule": rule,
									"slot_index": -2  # -2 indicates enemy ability
								})
						else:
							items_to_proc.append({
								"item": ability,
								"rule": rule,
								"slot_index": -2
							})
	
	# Sort by trigger_priority (higher = earlier)
	#items_to_proc.sort_custom(func(a, b): return a.item.trigger_priority > b.item.trigger_priority)
	
	return items_to_proc

func collect_triggered_items_with_status(entity, trigger_type: Enums.TriggerType, trigger_status: Enums.StatusEffects) -> Array:
	# Collect items that trigger based on status effects.
	# Similar to collect_triggered_items but filters by status instead of stat.

	var items_to_proc = []
	
	if entity == combat_manager.player_entity:
		# Check weapon
		if entity.inventory.weapon_slot:
			for rule in entity.inventory.weapon_slot.rules:
				if rule.trigger_type == trigger_type:
					# Check if rule has status filter
					if rule.trigger_status != Enums.StatusEffects.NONE:
						if rule.trigger_status == trigger_status:
							items_to_proc.append({
								"item": entity.inventory.weapon_slot,
								"rule": rule,
								"slot_index": -1
							})
					else:
						# No status filter, triggers on any status change
						items_to_proc.append({
							"item": entity.inventory.weapon_slot,
							"rule": rule,
							"slot_index": -1
						})
		
		# Check inventory
		for i in range(entity.inventory.item_slots.size()):
			var item = entity.inventory.item_slots[i]
			if item:
				for rule in item.rules:
					if rule.trigger_type == trigger_type:
						if rule.trigger_status != Enums.StatusEffects.NONE:
							if rule.trigger_status == trigger_status:
								items_to_proc.append({
									"item": item,
									"rule": rule,
									"slot_index": i
								})
						else:
							items_to_proc.append({
								"item": item,
								"rule": rule,
								"slot_index": i
							})
	
	else:  # Enemy
		for ability in entity.abilities:
			if ability:
				for rule in ability.rules:
					if rule.trigger_type == trigger_type:
						if rule.trigger_status != Enums.StatusEffects.NONE:
							if rule.trigger_status == trigger_status:
								items_to_proc.append({
									"item": ability,
									"rule": rule,
									"slot_index": -2
								})
						else:
							items_to_proc.append({
								"item": ability,
								"rule": rule,
								"slot_index": -2
							})
	
	#items_to_proc.sort_custom(func(a, b): return a.item.trigger_priority > b.item.trigger_priority)
	
	return items_to_proc

# ===== VALIDATION =====

func can_item_trigger(entity, item: Item, rule: ItemRule, trigger_type: Enums.TriggerType) -> bool:
	# Determine if an item can trigger based on its constraints.
	# Checks: trigger_only_once, trigger_only_first_turn

	# Check trigger_only_once
	if item.trigger_only_once:
		if has_item_triggered(entity, item):
			return false
	
	# Check trigger_only_first_turn
	if item.trigger_only_first_turn:
		if combat_manager.turn_number > 1:
			return false
	
	return true

# ===== OCCURRENCE SYSTEM =====

func increment_occurrence_counter(entity, item: Item, trigger_type: Enums.TriggerType):
	# Increment the occurrence counter for this item/trigger combination.

	if not occurrence_counters.has(entity):
		occurrence_counters[entity] = {}
	
	if not occurrence_counters[entity].has(trigger_type):
		occurrence_counters[entity][trigger_type] = {}
	
	if not occurrence_counters[entity][trigger_type].has(item):
		occurrence_counters[entity][trigger_type][item] = 0
	
	occurrence_counters[entity][trigger_type][item] += 1

func check_occurrence_match(entity, item: Item, rule: ItemRule, trigger_type: Enums.TriggerType) -> bool:
	# Check if the current occurrence count matches the item's trigger_on_occurrence_number.
	
	# trigger_on_occurrence_number:
	# - 0 = trigger every time (default)
	# - 2 = trigger every 2nd time (2, 4, 6...)
	# - 3 = trigger every 3rd time (3, 6, 9...)

	# If no occurrence number set, always trigger
	if item.trigger_on_occurrence_number <= 0:
		return true
	
	# Get current count
	var count = get_occurrence_count(entity, item, trigger_type)
	
	# Check if count is a multiple of the occurrence number
	return (count % item.trigger_on_occurrence_number) == 0

func get_occurrence_count(entity, item: Item, trigger_type: Enums.TriggerType) -> int:
	"""Get the current occurrence count for this item/trigger."""
	if not occurrence_counters.has(entity):
		return 0
	if not occurrence_counters[entity].has(trigger_type):
		return 0
	if not occurrence_counters[entity][trigger_type].has(item):
		return 0
	
	return occurrence_counters[entity][trigger_type][item]

func reset_occurrence_counters_per_turn(entity):
	# Reset occurrence counters for items with occurrence_resets_per_turn = true.
	# Called at the start of each turn.

	if entity == combat_manager.player_entity:
		# Check weapon
		if entity.inventory.weapon_slot and entity.inventory.weapon_slot.occurrence_resets_per_turn:
			_reset_item_occurrences(entity, entity.inventory.weapon_slot)
		
		# Check inventory
		for item in entity.inventory.item_slots:
			if item and item.occurrence_resets_per_turn:
				_reset_item_occurrences(entity, item)
	
	else:  # Enemy
		for ability in entity.abilities:
			if ability and ability.occurrence_resets_per_turn:
				_reset_item_occurrences(entity, ability)

func _reset_item_occurrences(entity, item: Item):
	"""Reset all occurrence counters for a specific item."""
	if not occurrence_counters.has(entity):
		return
	
	for trigger_type in occurrence_counters[entity].keys():
		if occurrence_counters[entity][trigger_type].has(item):
			occurrence_counters[entity][trigger_type][item] = 0

# ===== TRIGGER TRACKING =====

func mark_item_as_triggered(entity, item: Item):
	"""Mark an item as having triggered (for trigger_only_once)."""
	if not triggered_once_items.has(entity):
		triggered_once_items[entity] = {}
	
	triggered_once_items[entity][item] = true

func has_item_triggered(entity, item: Item) -> bool:
	"""Check if an item has already triggered this combat."""
	if not triggered_once_items.has(entity):
		return false
	
	return triggered_once_items[entity].get(item, false)

# ===== RESET FUNCTIONS =====

func reset_all_items(entity):
	# Reset all item states for this entity.
	# Called at combat start and combat end.

	# Clear occurrence counters
	if occurrence_counters.has(entity):
		occurrence_counters[entity].clear()
	
	# Clear trigger_only_once tracking
	if triggered_once_items.has(entity):
		triggered_once_items[entity].clear()

func reset_per_turn_items(entity):
	# Reset per-turn item states.
	# Called at the start of each turn.

	reset_occurrence_counters_per_turn(entity)

# ===== UTILITY FUNCTIONS =====

func count_items_with_category(entity, category: String) -> int:
	# Count how many items the entity has with a specific category.
	# Used for repeat_rules_for_category calculations.

	var count = 0
	
	if entity == combat_manager.player_entity:
		# Check weapon
		if entity.inventory.weapon_slot:
			if category in entity.inventory.weapon_slot.categories:
				count += 1
		
		# Check inventory
		for item in entity.inventory.item_slots:
			if item:
				if category in item.categories:
					count += 1
	
	else:  # Enemy
		# Enemies don't have categories on abilities (yet)
		pass
	
	return count