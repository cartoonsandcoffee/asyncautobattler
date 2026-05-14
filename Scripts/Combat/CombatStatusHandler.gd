class_name CombatStatusHandler
extends Node

## Centralized status effect management system
## Handles application, removal, and turn-start processing of all status effects

# Signals
signal status_gained_triggered(entity, status: Enums.StatusEffects, stacks: int, item: Item)
signal status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int)
signal overheal_triggered(entity, amount: int)
signal acid_proc_triggered(entity, amount: int)
signal enemy_status_gained_triggered(entity, status: Enums.StatusEffects, stacks: int)
signal enemy_status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int)

var combat_manager
var stat_handler: CombatStatHandler
var game_colors: GameColors


func _init(manager, stat_handler_ref: CombatStatHandler):
	combat_manager = manager
	stat_handler = stat_handler_ref
	game_colors = GameColors.new()
	
# ===== STATUS APPLICATION =====

func apply_status(entity, status: Enums.StatusEffects, stacks: int, source_item: Item = null):
	# Apply status effect stacks to an entity.
	# Automatically triggers ON_STATUS_GAINED items.

	if not entity.status_effects or stacks <= 0:
		return
	
	var old_value = get_status_value(entity, status)
	
	# Apply the status stacks
	entity.status_effects.increment_status(status, stacks)
	
	var new_value = get_status_value(entity, status)
	
	# Trigger ON_STATUS_GAINED items
	status_gained_triggered.emit(entity, status, new_value, source_item)

	var opponent = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity
	enemy_status_gained_triggered.emit(opponent, status, new_value)



func remove_status(entity, status: Enums.StatusEffects, stacks: int):
	# Remove status effect stacks from an entity.
	# Automatically triggers ON_STATUS_REMOVED items when any amount is removed.

	if not entity.status_effects or stacks <= 0:
		return
	
	var old_value = get_status_value(entity, status)
	
	if old_value <= 0:
		return  # Nothing to remove
	
	# Remove the stacks
	entity.status_effects.decrement_status(status, stacks)
	
	var new_value = get_status_value(entity, status)

	# Handle Blessing
	if status == Enums.StatusEffects.BLESSING:
		_process_blessing(entity, stacks)

	# Trigger ON_STATUS_REMOVED items (even if partial removal)
	status_removed_triggered.emit(entity, status, new_value)

	var opponent = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity
	enemy_status_removed_triggered.emit(opponent, status, new_value)	


# ===== STATUS GETTERS =====

func get_status_value(entity, status: Enums.StatusEffects) -> int:
	if not entity.status_effects:
		return 0
	
	match status:
		Enums.StatusEffects.POISON:
			return entity.status_effects.poison
		Enums.StatusEffects.ACID:
			return entity.status_effects.acid
		Enums.StatusEffects.THORNS:
			return entity.status_effects.thorns
		Enums.StatusEffects.REGENERATION:
			return entity.status_effects.regeneration
		Enums.StatusEffects.BURN:
			return entity.status_effects.burn
		Enums.StatusEffects.BLIND:
			return entity.status_effects.blind
		Enums.StatusEffects.BLESSING:
			return entity.status_effects.blessing
		Enums.StatusEffects.STUN:
			return entity.status_effects.stun
	
	return 0

# ===== TURN START PROCESSING =====

func has_any(entity) -> bool:
	return (entity.status_effects.poison > 0 or
		entity.status_effects.burn > 0 or
		entity.status_effects.acid > 0 or
		entity.status_effects.regeneration > 0 or
		entity.status_effects.blind > 0 or
		entity.status_effects.thorns > 0 or
		entity.status_effects.blessing > 0)

func has_any_turn_start(entity) -> bool:
	return (entity.status_effects.poison > 0 or
		entity.status_effects.acid > 0)

func has_any_turn_end(entity) -> bool:
	return (entity.status_effects.burn > 0 or
		entity.status_effects.regeneration > 0 or
		entity.status_effects.blind > 0 or
		entity.status_effects.thorns > 0)

func process_turn_start_status_effects(entity):
	# Process all status effects at the start of an entity's turn.
	# This is called from CombatManager during the turn sequence.
	
	if not entity.status_effects:
		return
	
	if not has_any_turn_start(entity):
		return

	#combat_manager.add_to_combat_log_string("%s's status effects:" % CombatLog.color_entity(combat_manager.get_entity_name(entity)))

	# Process each status effect type
	_process_acid(entity)
	_process_poison(entity)


# ===== INDIVIDUAL STATUS PROCESSORS =====

func _process_poison(entity):
	# Poison: Damages HP but is BLOCKED by shield.
	# If shield > 0, poison does nothing but still decrements by 1.
	
	if entity.status_effects.poison <= 0:
		return
	
	var damage = entity.status_effects.poison
	
	# Check if entity has shield
	if entity.stats.shield_current > 0:
		# Shield blocks poison - no damage, but poison still decrements
		combat_manager.event_queue.enqueue(CombatEvent.log(CombatLog.fmt_status_blocked(_get_entity_name(entity), Enums.Stats.SHIELD, Enums.StatusEffects.POISON, damage)))
	else:
		combat_manager.event_queue.enqueue(CombatEvent.modify_stat(entity, Enums.Stats.HITPOINTS, -damage, Enums.StatType.CURRENT, null, "poison"))
		combat_manager.event_queue.enqueue(CombatEvent.status_proc_visual(entity, Enums.StatusEffects.POISON, Enums.Stats.HITPOINTS, -damage))
	
	# Always decrement poison by 1
	combat_manager.event_queue.enqueue(CombatEvent.remove_status(entity, Enums.StatusEffects.POISON, 1))

func _process_burn(entity):
	# Burn: Damages HP based on burn_damage stat * burn stacks.
	# Goes through damage system (respects shield, can trigger EXPOSED).
	# Decrements by 1 after dealing damage.
	# Formula: damage = source.stats.burn_damage_current * target.burn_stacks
	
	if entity.status_effects.burn <= 0:
		return
	
	# Get the source of the burn (opposite entity)
	var burn_source = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity
	
	# Calculate burn damage: burn_damage stat * burn stacks
	var burn_damage_per_stack = burn_source.stats.burn_damage_current if burn_source else GameStats.BASE_BURN_DAMAGE
	var total_damage = burn_damage_per_stack
	
	# LOG the burn proc
	combat_manager.event_queue.enqueue(CombatEvent.log(CombatLog.fmt_status_proc(Enums.StatusEffects.BURN, _get_entity_name(entity), total_damage)))

	# Apply burn damage through damage system
	combat_manager.event_queue.enqueue(CombatEvent.deal_damage(burn_source, entity, total_damage, "burn"))
		
	# Decrement burn by 1
	combat_manager.event_queue.enqueue(CombatEvent.remove_status(entity, Enums.StatusEffects.BURN, 1))

	if _check_for_persistent_burn_rule(burn_source): #check if the entity applying the burn has "burn triggers twice" item.
		_process_burn_second_time(entity)

func _process_burn_second_time(entity):
	# Copy of other process_burn function for when special rules allow for multiple burn procs
	
	if entity.status_effects.burn <= 0:
		return

	# Get the source of the burn (opposite entity)
	var burn_source = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity
	
	# Calculate burn damage: burn_damage stat * burn stacks
	var burn_damage_per_stack = burn_source.stats.burn_damage_current if burn_source else GameStats.BASE_BURN_DAMAGE
	var total_damage = burn_damage_per_stack
	
	# LOG the burn proc
	combat_manager.event_queue.enqueue(CombatEvent.log(CombatLog.fmt_status_proc(Enums.StatusEffects.BURN, _get_entity_name(entity), total_damage)))

	# Apply burn damage through damage system
	combat_manager.event_queue.enqueue(CombatEvent.deal_damage(burn_source, entity, total_damage, "burn"))
		
	# Decrement burn by 1
	combat_manager.event_queue.enqueue(CombatEvent.remove_status(entity, Enums.StatusEffects.BURN, 1))

func _process_acid(entity):
	# Acid: Damages shield only, does NOT decrement naturally. Can trigger EXPOSED when shield reaches 0.

	if entity.status_effects.acid <= 0:
		return
	
	var damage = entity.status_effects.acid
	
	# Only damage if they have shield
	if entity.stats.shield_current > 0:
		var old_shield = entity.stats.shield_current
		var damage_dealt = mini(damage, entity.stats.shield_current)
		var new_shield = max(0, old_shield - damage_dealt)

		# Apply to shield
		combat_manager.event_queue.enqueue(CombatEvent.modify_stat(entity, Enums.Stats.SHIELD, -damage_dealt, Enums.StatType.CURRENT, null, "acid"))

		# Get the source of the acid (opposite entity)
		var acid_source = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity
	
		# Visual feedback
		var stat_for_visual = Enums.Stats.SHIELD
		if new_shield == 0:
			stat_for_visual = Enums.Stats.EXPOSED
		
		combat_manager.event_queue.enqueue(CombatEvent.status_proc_visual(entity, Enums.StatusEffects.ACID, stat_for_visual, -damage_dealt))
		acid_proc_triggered.emit(acid_source, damage_dealt)
	else:
		combat_manager.event_queue.enqueue(CombatEvent.log("   %s: %s has no %s to damage." % [
			CombatLog.color_status(Enums.StatusEffects.ACID),
			CombatLog.color_entity(_get_entity_name(entity)),
			CombatLog.color_stat(Enums.Stats.SHIELD)
		]))
	# NOTE: Acid does NOT decrement naturally

func _process_regeneration(entity):
	# Regeneration: Heals HP, decrements by 1.

	if entity.status_effects.regeneration <= 0:
		return
	
	var heal_amount:int = entity.status_effects.regeneration
	var old_hp:int = entity.stats.hit_points_current
	
	var max_hp: int = entity.stats.hit_points
	var new_hp: int = min(old_hp + heal_amount, max_hp)   # preview
	var actual_heal: int  = new_hp - old_hp
	var overheal: int = heal_amount - actual_heal

	combat_manager.event_queue.enqueue(CombatEvent.modify_stat(entity, Enums.Stats.HITPOINTS, heal_amount))
	combat_manager.event_queue.enqueue(CombatEvent.status_proc_visual(entity, Enums.StatusEffects.REGENERATION, Enums.Stats.HITPOINTS, heal_amount))

	if overheal > 0:
		overheal_triggered.emit(entity, overheal)


	# Decrement regen by 1
	combat_manager.event_queue.enqueue(CombatEvent.remove_status(entity, Enums.StatusEffects.REGENERATION, 1))

func _process_blind(entity):
	# Blind: Placeholder behavior - currently just decrements.
	# TODO: Implement damage halving during attack phase.

	if entity.status_effects.blind <= 0:
		return
	
	# Decrement blind by 1
	combat_manager.event_queue.enqueue(CombatEvent.remove_status(entity, Enums.StatusEffects.BLIND, 1))

func _process_blessing(entity, _stacks: int):
	# Blessing: Special behavior on removal (heal 3 and gain 1 damage).
	var heal_per_stack = GameStats.BASE_BLESSING_HEAL
	var damage_per_stack = GameStats.BASE_BLESSING_DAMAGE
	
	var doublings = _count_persistent_blessing_doublings(entity)
	for i in range(doublings):
		heal_per_stack *= 2
		damage_per_stack *= 2
	
	var total_heal = heal_per_stack * _stacks
	var total_damage = damage_per_stack * _stacks

	var old_hp: int = entity.stats.hit_points_current
	var max_hp: int = entity.stats.hit_points
	var actual_heal: int = min(total_heal, max_hp - old_hp)
	var overheal: int = total_heal - actual_heal

	if total_heal > 0:
		combat_manager.event_queue.enqueue_next(CombatEvent.modify_stat(entity, Enums.Stats.HITPOINTS, total_heal, Enums.StatType.CURRENT, null, "Blessing"))
	if total_damage > 0:
		entity.stats.modify_combat_temp_stat(Enums.Stats.DAMAGE, total_damage)

	# LOG with colors
	if actual_heal > 0:
		combat_manager.event_queue.enqueue_next(CombatEvent.status_proc_visual(entity, Enums.StatusEffects.BLESSING, Enums.Stats.HITPOINTS, actual_heal))

	if overheal > 0:
		overheal_triggered.emit(entity, overheal)

	combat_manager.event_queue.enqueue_next(CombatEvent.status_proc_visual(entity, Enums.StatusEffects.BLESSING, Enums.Stats.DAMAGE, _stacks))

	var overheal_str: String = ""
	var actual_heal_str: String = ""

	if overheal > 0:
		overheal_str = "(Overheal of %s)" % [CombatLog.color(str(overheal), CombatLog._stat_color(Enums.Stats.HITPOINTS)) + CombatLog.icon_stat(Enums.Stats.HITPOINTS),]
	if actual_heal > 0:
		actual_heal_str = "healed for %s (%d → %d)," % [CombatLog.color(str(actual_heal), CombatLog._stat_color(Enums.Stats.HITPOINTS)) + CombatLog.icon_stat(Enums.Stats.HITPOINTS), old_hp, old_hp + actual_heal]
	else:
		actual_heal_str = "%s full. %s," % [CombatLog.color(str("Hitpoints"), CombatLog._stat_color(Enums.Stats.HITPOINTS)), overheal_str]
	combat_manager.event_queue.enqueue_next(CombatEvent.log(
		"      %s: %s %s gained %s attack damage." % [
			CombatLog.color_status(Enums.StatusEffects.BLESSING),
			CombatLog.color_entity(_get_entity_name(entity)),
			actual_heal_str,
			CombatLog.color(str(total_damage), CombatLog._stat_color(Enums.Stats.DAMAGE)) + CombatLog.icon_stat(Enums.Stats.DAMAGE)
		]))


# ===== TURN END PROCESSING =====

func process_turn_end_status_effects(entity):
	# Process status effects that trigger at turn end.

	if not entity.status_effects:
		return
	
	if not has_any_turn_end(entity):
		return

	#combat_manager.add_to_combat_log_string("%s's status effects:" % CombatLog.color_entity(combat_manager.get_entity_name(entity)))

	_process_burn(entity)  
	_process_regeneration(entity)  
	_process_blind(entity)  


# ===== THORNS REFLECTION =====

func enqueue_thorns_if_present(attacker, target) -> void:
	# Called from ATTACK_ANIMATION handler after each strike.
	# Enqueues thorns damage and removal into the event queue instead of awaiting inline.
	
	if not target.status_effects or target.status_effects.thorns <= 0:
		return
	
	var thorns_damage = target.status_effects.thorns
	var doublings = _count_persistent_thorn_doublings(target)
	for i in range(doublings):
		thorns_damage *= 2

	# Enqueue thorns damage — resolves in queue after the hit that triggered it
	combat_manager.event_queue.enqueue(CombatEvent.deal_damage(target, attacker, thorns_damage, "thorns"))
	
	# Mark for removal at turn end (existing mechanism unchanged)
	target.status_effects.thorns_triggered(true)

func process_thorns_removal(entity):
	#JDM: Thorn removal should be called after turn_end_status_effects of opponent and only removed if triggered
	if entity.status_effects.thorns_triggered_for_removal:
		combat_manager.event_queue.enqueue(CombatEvent.remove_status(entity, Enums.StatusEffects.THORNS, entity.status_effects.thorns))
		entity.status_effects.thorns_triggered(false) # Set as "not triggered" for the next turn

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

# ==== PERSISTENT RULE FUNCTIONS =====
func _check_for_persistent_burn_rule(entity) -> bool:
	# Get entity's inventory
	var inventory = null
	if entity == combat_manager.player_entity:
		inventory = Player.inventory
	elif "inventory" in entity:
		inventory = entity.inventory
	
	if not inventory:
		return false
	
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
			if rule.trigger_type != Enums.TriggerType.PERSISTENT:
				continue
						
			# Evaluate condition
			if rule.has_condition:
				if not combat_manager.condition_evaluator.evaluate_condition(rule, entity, entity):
					continue
			
			# Apply effect
			if _check_special_rule(rule):
				return true

	return false

func _count_persistent_thorn_doublings(entity) -> int:
	var inventory = null
	var other_entity = null

	if entity == combat_manager.player_entity:
		inventory = Player.inventory
		other_entity = combat_manager.enemy_entity
	elif "inventory" in entity:
		inventory = entity.inventory
		other_entity = combat_manager.player_entity

	if not inventory:
		return 0
	
	var all_items = []
	if inventory.weapon_slot:
		all_items.append(inventory.weapon_slot)
	for item in inventory.item_slots:
		if item:
			all_items.append(item)
	
	var count: int = 0
	for item in all_items:
		for rule in item.rules:
			if rule.trigger_type != Enums.TriggerType.PERSISTENT:
				continue
			if rule.special_string != "double_thorn_damage":
				continue
			if rule.has_condition:
				if not combat_manager.condition_evaluator.evaluate_condition(rule, entity, other_entity):
					continue
			count += 1
	
	return count

func _count_persistent_blessing_doublings(entity) -> int:
	var inventory = null
	var other_entity = null

	if entity == combat_manager.player_entity:
		inventory = Player.inventory
		other_entity = combat_manager.enemy_entity
	elif "inventory" in entity:
		inventory = entity.inventory
		other_entity = combat_manager.player_entity

	if not inventory:
		return 0
	
	var all_items = []
	if inventory.weapon_slot:
		all_items.append(inventory.weapon_slot)
	for item in inventory.item_slots:
		if item:
			all_items.append(item)
	
	var count: int = 0
	for item in all_items:
		for rule in item.rules:
			if rule.trigger_type != Enums.TriggerType.PERSISTENT:
				continue
			if rule.special_string != "double_blessing":
				continue
			if rule.has_condition:
				if not combat_manager.condition_evaluator.evaluate_condition(rule, entity, other_entity):
					continue
			count += 1
	
	return count


func _check_special_rule(rule: ItemRule) -> bool:
	# Apply persistent effect to damage/strikes/burn current values.
	
	# Handle special strings (multiplicative)
	if rule.special_string != "":
		match rule.special_string:
			"extra_burn_proc":
				return true
	return false

# ===== RESET FUNCTIONS =====

func reset_all_statuses(entity):
	"""Reset all status effects for an entity."""
	if entity.status_effects:
		entity.status_effects.reset_statuses()
