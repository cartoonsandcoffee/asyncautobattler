class_name CombatStatusHandler
extends Node

## Centralized status effect management system
## Handles application, removal, and turn-start processing of all status effects

# Signals
signal status_gained_triggered(entity, status: Enums.StatusEffects, stacks: int)
signal status_removed_triggered(entity, status: Enums.StatusEffects, stacks: int)
signal overheal_triggered(entity, amount: int)

var combat_manager
var stat_handler: CombatStatHandler
var game_colors: GameColors


func _init(manager, stat_handler_ref: CombatStatHandler):
	combat_manager = manager
	stat_handler = stat_handler_ref
	game_colors = GameColors.new()

# ===== STATUS APPLICATION =====

func apply_status(entity, status: Enums.StatusEffects, stacks: int):
	# Apply status effect stacks to an entity.
	# Automatically triggers ON_STATUS_GAINED items.

	if not entity.status_effects or stacks <= 0:
		return
	
	var old_value = get_status_value(entity, status)
	
	# Apply the status stacks
	entity.status_effects.increment_status(status, stacks)
	
	var new_value = get_status_value(entity, status)
	
	var combat_panel = combat_manager.get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		combat_panel.spawn_status_box_update(entity, status, new_value)
			
	# Trigger ON_STATUS_GAINED items
	status_gained_triggered.emit(entity, status, new_value)


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

	var combat_panel = combat_manager.get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		combat_panel.spawn_status_box_update(entity, status, new_value)

	# Log
	#_log_status_change(entity, status, old_value, new_value, false)
	if new_value > 0:
		combat_manager.add_to_combat_log_string("   %s loses 1 %s (remaining: %d)." % [
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_status(Enums.get_status_string(status)),
				new_value
			])
	else:
		combat_manager.add_to_combat_log_string("   %s's %s wears off." % [
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_status(Enums.get_status_string(status))
			])

	# Trigger ON_STATUS_REMOVED items (even if partial removal)
	status_removed_triggered.emit(entity, status, new_value)


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

func process_turn_start_status_effects(entity):
	# Process all status effects at the start of an entity's turn.
	# This is called from CombatManager during the turn sequence.
	
	if not entity.status_effects:
		return
	
	if not has_any(entity):
		combat_manager.add_to_combat_log_string("   (no status effects.)")
		return		

	# Process each status effect type
	await _process_acid(entity)
	await _process_poison(entity)

	# New timing code instead of all the CombatSpeed.create_timer(...) calls for visual procs
	var combat_panel = get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		await combat_panel.wait_for_indicator_queue_to_finish()


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
		combat_manager.add_to_combat_log_string("   %s: %s's %s blocks %s poison damage" % [
				combat_manager.color_status("Poison"),
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_stat("Shield"),
				combat_manager.color_text(str(damage), Color.WHITE)
			])
	else:
		# No shield - poison damages HP directly
		var old_hp = entity.stats.hit_points_current
		stat_handler.change_stat(entity, Enums.Stats.HITPOINTS, -damage)
		var new_hp = entity.stats.hit_points_current

		combat_manager.add_to_combat_log_string("   %s: %s's %s decreased by %s (%d -> %d)" % [
				combat_manager.color_status("Poison"),
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_stat("hitpoints"),
				combat_manager.color_text(str(damage), game_colors.stats.poison),
				old_hp,
				new_hp
			])

		combat_manager.status_proc.emit(entity, Enums.StatusEffects.POISON, Enums.Stats.HITPOINTS, -damage)
	
	# Always decrement poison by 1
	remove_status(entity, Enums.StatusEffects.POISON, 1)

func _process_burn(entity):
	# Burn: Damages HP based on burn_damage stat * burn stacks.
	# Goes through damage system (respects shield, can trigger EXPOSED).
	# Decrements by 1 after dealing damage.
	# Formula: damage = source.stats.burn_damage_current * target.burn_stacks
	
	if entity.status_effects.burn <= 0:
		return
	
	var burn_stacks = entity.status_effects.burn
	
	# Get the source of the burn (opposite entity)
	var burn_source = combat_manager.enemy_entity if entity == combat_manager.player_entity else combat_manager.player_entity
	
	# Calculate burn damage: burn_damage stat * burn stacks
	var burn_damage_per_stack = burn_source.stats.burn_damage_current if burn_source else 4
	var total_damage = burn_damage_per_stack
	
	# LOG the burn proc
	combat_manager.add_to_combat_log_string("   %s: %s takes %s damage." % [
			combat_manager.color_status("Burn"),
			combat_manager.color_entity(_get_entity_name(entity)),
			combat_manager.color_text(str(total_damage), game_colors.stats.burn)])

	# Apply burn damage through damage system
	# This respects shield and can trigger EXPOSED
	if combat_manager.damage_system:
		await combat_manager.damage_system.apply_damage(entity, total_damage, burn_source, "burn")
		
	# Decrement burn by 1
	remove_status(entity, Enums.StatusEffects.BURN, 1)

func _process_acid(entity):
	# Acid: Damages shield only, does NOT decrement naturally. Can trigger EXPOSED when shield reaches 0.

	if entity.status_effects.acid <= 0:
		return
	
	var damage = entity.status_effects.acid
	
	# Only damage if they have shield
	if entity.stats.shield_current > 0:
		var old_shield = entity.stats.shield_current
		var damage_dealt = mini(damage, entity.stats.shield_current)
		
		# Apply to shield
		stat_handler.change_stat(entity, Enums.Stats.SHIELD, -damage_dealt)
		var new_shield = entity.stats.shield_current

		# LOG with colors
		combat_manager.add_to_combat_log_string(
			"   %s: %s's %s decreased by %s (%d -> %d)" % [
				combat_manager.color_status("Acid"),
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_stat("shield"),
				combat_manager.color_text(str(damage_dealt), game_colors.stats.acid),
				old_shield,
				new_shield
			]
		)

		# Visual feedback
		var stat_for_visual = Enums.Stats.SHIELD
		if entity.stats.shield_current == 0:
			stat_for_visual = Enums.Stats.EXPOSED
		
		combat_manager.status_proc.emit(entity, Enums.StatusEffects.ACID, stat_for_visual, -damage_dealt)
		
	else:
		combat_manager.add_to_combat_log_string("   %s: %s has no shield to damage" % [
				combat_manager.color_status("Acid"),
				combat_manager.color_entity(_get_entity_name(entity))])

	# NOTE: Acid does NOT decrement naturally

func _process_regeneration(entity):
	# Regeneration: Heals HP, decrements by 1.

	if entity.status_effects.regeneration <= 0:
		return
	
	var heal_amount:int = entity.status_effects.regeneration
	var old_hp:int = entity.stats.hit_points_current

	# Heal through stat handler
	stat_handler.change_stat(entity, Enums.Stats.HITPOINTS, heal_amount)
	var new_hp: int  = entity.stats.hit_points_current
	var actual_heal: int  = new_hp - old_hp
	var overheal: int = heal_amount - actual_heal

	if actual_heal > 0:
		combat_manager.add_to_combat_log_string("   %s: %s's %s increased by %s (%d -> %d)" % [
				combat_manager.color_status("Regeneration"),
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_stat("hitpoints"),
				combat_manager.color_text(str(actual_heal), game_colors.stats.regeneration),
				old_hp, new_hp])
		
		combat_manager.status_proc.emit(entity, Enums.StatusEffects.REGENERATION, Enums.Stats.HITPOINTS, heal_amount)

		if overheal > 0:
			overheal_triggered.emit(entity, overheal)
	else:
		overheal_triggered.emit(entity, overheal)
		combat_manager.add_to_combat_log_string("   %s: %s is already at full %s.  (Overheal %s)" % [
				combat_manager.color_status("Regeneration"),
				combat_manager.color_entity(_get_entity_name(entity)),
				combat_manager.color_stat("hitpoints"),
				str(overheal)
			])

	# Decrement regen by 1
	remove_status(entity, Enums.StatusEffects.REGENERATION, 1)

func _process_blind(entity):
	# Blind: Placeholder behavior - currently just decrements.
	# TODO: Implement damage halving during attack phase.

	if entity.status_effects.blind <= 0:
		return
	
	# Decrement blind by 1
	remove_status(entity, Enums.StatusEffects.BLIND, 1)

func _process_blessing(entity, _stacks: int):
	# Blessing: Special behavior on removal (heal 3 and gain 1 damage).
	var heal_per_stack = 3
	var damage_per_stack = 1
    
	var total_heal = heal_per_stack * _stacks
	var total_damage = damage_per_stack * _stacks

	var old_hp: int = entity.stats.hit_points_current

	if total_heal > 0:
		combat_manager.damage_system.heal_entity(entity, total_heal, null)
	if total_damage > 0:
		stat_handler.change_stat(entity, Enums.Stats.DAMAGE, total_damage, Enums.StatType.CURRENT)

	var new_hp: int  = entity.stats.hit_points_current
	var actual_heal: int  = new_hp - old_hp
	var overheal: int = total_heal - actual_heal

	# LOG with colors
	var str_overheal: String = ""
	if overheal > 0:
		str_overheal = "(Overheal for %s.)" % [combat_manager.color_text(str(overheal), game_colors.stats.hit_points)]

	if actual_heal > 0:
		combat_manager.status_proc.emit(entity, Enums.StatusEffects.BLESSING, Enums.Stats.HITPOINTS, actual_heal)

	combat_manager.add_to_combat_log_string(
		"   %s: Removed %d from %s. Healing %s HP %sand gaining %s attack damage." % [
			combat_manager.color_status("Blessing"),
			_stacks,
			combat_manager.color_entity(_get_entity_name(entity)),
			combat_manager.color_text(str(total_heal), game_colors.stats.hit_points),
			str_overheal,
			combat_manager.color_text(str(total_damage), game_colors.stats.damage)
		]
	)

	if overheal > 0:
		overheal_triggered.emit(entity, overheal)

	combat_manager.status_proc.emit(entity, Enums.StatusEffects.BLESSING, Enums.Stats.DAMAGE, _stacks)


# ===== TURN END PROCESSING =====

func process_turn_end_status_effects(entity):
	# Process status effects that trigger at turn end.
	# Currently no status effects proc at turn end (thorns removed on hit instead).

	if not entity.status_effects:
		return
	
	await _process_burn(entity)  
	await _process_regeneration(entity)  
	await _process_blind(entity)  

	#JDM: Thorns should remove on turn_end so that way they proc for each hit/strike as a counter to many strikes

	# New timing code instead of all the CombatSpeed.create_timer(...) calls for visual procs
	var combat_panel = get_tree().get_first_node_in_group("combat_panel")
	if combat_panel:
		await combat_panel.wait_for_indicator_queue_to_finish()

# ===== THORNS REFLECTION =====

func process_thorns_reflection(attacker, target):
	# Process thorns reflection damage.
	# Called when an entity with thorns is hit by an attack.
	
	# Thorns:
	# - Reflects damage back to attacker
	# - Damages BOTH shield and HP (goes through shield first, then HP)
	# - Is REMOVED after reflecting (when owner is hit)

	if not target.status_effects or target.status_effects.thorns <= 0:
		return
	
	var thorns_damage = target.status_effects.thorns
	var attacker_name: String = _get_entity_name(attacker)
	var target_name: String = _get_entity_name(target)

	# LOG thorns reflection
	combat_manager.add_to_combat_log_string("   %s: %s takes %s damage from %s." % [
			combat_manager.color_status("Thorns"),
			combat_manager.color_entity(attacker_name),
			combat_manager.color_text(str(thorns_damage), game_colors.stats.thorns),
			combat_manager.color_entity(target_name)
		])

	# Apply thorns damage through damage system (respects shield)
	if combat_manager.damage_system:
		await combat_manager.damage_system.apply_damage(attacker, thorns_damage, target, "thorns")
	
	# Remove ALL thorns after reflecting
	remove_status(target, Enums.StatusEffects.THORNS, thorns_damage)

# ===== HELPER FUNCTIONS =====

func _log_status_change(entity, status: Enums.StatusEffects, old_value: int, new_value: int, is_gain: bool):
	var entity_name = _get_entity_name(entity)
	var status_name = Enums.get_status_string(status)
	var change = new_value - old_value
	var color = _get_color_for_status(status)

	if is_gain:
		combat_manager.add_to_combat_log_string(
			"  %s gains %d %s (total: %d)" % [entity_name, change, status_name, new_value], color
		)
	else:
		combat_manager.add_to_combat_log_string(
			"  %s loses %d %s (remaining: %d)" % [entity_name, abs(change), status_name, new_value], color
		)

func _get_entity_name(entity) -> String:
	"""Get the display name of an entity."""
	if entity == combat_manager.player_entity:
		return "Player"
	elif entity == combat_manager.enemy_entity:
		if entity is Enemy:
			return entity.enemy_name
		return "Enemy"
	return "Unknown"

# ===== RESET FUNCTIONS =====

func reset_all_statuses(entity):
	"""Reset all status effects for an entity."""
	if entity.status_effects:
		entity.status_effects.reset_statuses()

func _get_color(color_name: String) -> Color:
	# Get color from GameColors if available, otherwise use fallback.
	if game_colors and game_colors.stats:
		match color_name:
			"poison":
				return game_colors.stats.poison
			"burn":
				return game_colors.stats.burn
			"acid":
				return game_colors.stats.acid
			"thorns":
				return game_colors.stats.thorns
			"regeneration":
				return game_colors.stats.regeneration
			"shield":
				return game_colors.stats.shield
			"stun":
				return game_colors.stats.stun
			"status_header":
				return Color.GREEN_YELLOW
	
	# Fallback colors
	match color_name:
		"poison":
			return Color.PURPLE
		"burn":
			return Color.ORANGE
		"acid":
			return Color.GREEN
		"thorns":
			return Color.DARK_ORANGE
		"regeneration":
			return Color.LIGHT_GREEN
		"shield":
			return Color.CYAN
		"status_header":
			return Color.GREEN_YELLOW
	
	return Color.WHITE

func _get_color_for_status(status: Enums.StatusEffects) -> Color:
	"""Get the appropriate color for a status effect."""
	match status:
		Enums.StatusEffects.POISON:
			return _get_color("poison")
		Enums.StatusEffects.BURN:
			return _get_color("burn")
		Enums.StatusEffects.ACID:
			return _get_color("acid")
		Enums.StatusEffects.THORNS:
			return _get_color("thorns")
		Enums.StatusEffects.REGENERATION:
			return _get_color("regeneration")
		Enums.StatusEffects.STUN:
			return _get_color("stun")

	return Color.YELLOW

func _get_status_icon(status: Enums.StatusEffects) -> Texture2D:
	"""Get the icon texture for a status effect."""
	var icon_path = ""
	
	match status:
		Enums.StatusEffects.POISON:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_poison.tres"
		Enums.StatusEffects.BURN:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_burn.tres"
		Enums.StatusEffects.ACID:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_acid.tres"
		Enums.StatusEffects.THORNS:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_thorns.tres"
		Enums.StatusEffects.REGENERATION:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_regen.tres"
		Enums.StatusEffects.BLIND:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_blind.tres"
		Enums.StatusEffects.BLESSING:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_blessing.tres"
		Enums.StatusEffects.STUN:
			icon_path = "res://Resources/StatIcons/StatusIcons/status_stun.tres"	
	if icon_path != "":
		return load(icon_path)
	
	return null
