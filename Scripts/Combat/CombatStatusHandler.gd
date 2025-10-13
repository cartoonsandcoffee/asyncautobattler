class_name CombatStatusHandler
extends Node

## Centralized status effect management system
## Handles application, removal, and turn-start processing of all status effects

# Signals
signal status_applied(entity, status: Enums.StatusEffects, stacks: int)
signal status_removed(entity, status: Enums.StatusEffects, stacks: int)
signal status_gained_triggered(entity, status: Enums.StatusEffects)
signal status_removed_triggered(entity, status: Enums.StatusEffects)

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
	
	# Emit signals
	status_applied.emit(entity, status, stacks)
	
	# Log
	_log_status_change(entity, status, old_value, new_value, true)
	
	# Trigger ON_STATUS_GAINED items
	status_gained_triggered.emit(entity, status)

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
	
	# Emit signals
	status_removed.emit(entity, status, stacks)
	
	# Log
	_log_status_change(entity, status, old_value, new_value, false)
	
	# Trigger ON_STATUS_REMOVED items (even if partial removal)
	status_removed_triggered.emit(entity, status)

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

func process_turn_start_status_effects(entity):
	# Process all status effects at the start of an entity's turn.
	# This is called from CombatManager during the turn sequence.
	
	if not entity.status_effects:
		return
	
	combat_manager.add_to_combat_log_string(_get_entity_name(entity) + " status effects:", Color.GREEN_YELLOW)
	
	# Process each status effect type
	await _process_poison(entity)
	await _process_burn(entity)
	await _process_acid(entity)
	await _process_regeneration(entity)
	await _process_blind(entity)
	await _process_blessing(entity)

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
		combat_manager.add_to_combat_log_string("  %s's shield blocks %d poison damage!" % [_get_entity_name(entity), damage], Color.CYAN)
	else:
		# No shield - poison damages HP directly
		stat_handler.change_stat(entity, Enums.Stats.HITPOINTS, -damage)
		
		# Visual feedback
		combat_manager.animation_manager.play_damage_indicator(
			entity, damage, Enums.Stats.HITPOINTS,
			{
				"icon": _get_status_icon(Enums.StatusEffects.POISON),
				"color": _get_color("poison"),
				"source_name": "Poison"
			}
		)
		
		# Emit status proc signal
		combat_manager.status_proc.emit(entity, Enums.StatusEffects.POISON, Enums.Stats.HITPOINTS, damage)
	
	# Always decrement poison by 1
	remove_status(entity, Enums.StatusEffects.POISON, 1)
	
	await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))

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
	var burn_damage_per_stack = burn_source.stats.burn_damage_current if burn_source else 1
	var total_damage = burn_damage_per_stack * burn_stacks
	
	combat_manager.add_to_combat_log_string("  🔥 %s takes %d burn damage (%d×%d)" % [_get_entity_name(entity), total_damage, burn_damage_per_stack, burn_stacks], _get_color("burn"))
	
	# Visual feedback
	combat_manager.animation_manager.play_damage_indicator(
		entity, total_damage, Enums.Stats.HITPOINTS,
		{
			"icon": _get_status_icon(Enums.StatusEffects.BURN),
			"color": _get_color("burn"),
			"source_name": "Burn"
		}
	)
	
	# Apply burn damage through damage system
	# This respects shield and can trigger EXPOSED
	if combat_manager.damage_system:
		await combat_manager.damage_system.apply_damage(entity, total_damage, burn_source, "burn")
		
	# Emit status proc signal for UI
	combat_manager.status_proc.emit(entity, Enums.StatusEffects.BURN, Enums.Stats.HITPOINTS, total_damage)
	
	# Decrement burn by 1
	remove_status(entity, Enums.StatusEffects.BURN, 1)
	
	await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))

func _process_acid(entity):
	# Acid: Damages shield only, does NOT decrement naturally. Can trigger EXPOSED when shield reaches 0.

	if entity.status_effects.acid <= 0:
		return
	
	var damage = entity.status_effects.acid
	
	# Only damage if they have shield
	if entity.stats.shield_current > 0:
		var damage_dealt = mini(damage, entity.stats.shield_current)
		
		# Apply to shield
		stat_handler.change_stat(entity, Enums.Stats.SHIELD, -damage_dealt)
		
		# Visual feedback
		var stat_for_visual = Enums.Stats.SHIELD
		if entity.stats.shield_current == 0:
			stat_for_visual = Enums.Stats.EXPOSED
		
		combat_manager.animation_manager.play_damage_indicator(
			entity, damage_dealt, stat_for_visual,
			{
				"icon": _get_status_icon(Enums.StatusEffects.ACID),
				"color": _get_color("acid"),
				"source_name": "Acid"
			}
		)
		
		# Emit status proc signal
		combat_manager.status_proc.emit(entity, Enums.StatusEffects.ACID, stat_for_visual, damage_dealt)
		
		await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))
	
	# NOTE: Acid does NOT decrement naturally

func _process_regeneration(entity):
	# Regeneration: Heals HP, decrements by 1.

	if entity.status_effects.regeneration <= 0:
		return
	
	var heal_amount = entity.status_effects.regeneration
	
	# Heal through stat handler
	stat_handler.change_stat(entity, Enums.Stats.HITPOINTS, heal_amount)
	
	# Visual feedback
	combat_manager.animation_manager.play_damage_indicator(
		entity, heal_amount, Enums.Stats.HITPOINTS,
		{
			"icon": _get_status_icon(Enums.StatusEffects.REGENERATION),
			"color": _get_color("regeneration"),
			"source_name": "Regeneration"
		}
	)
	
	# Emit status proc signal
	combat_manager.status_proc.emit(entity, Enums.StatusEffects.REGENERATION, Enums.Stats.HITPOINTS, heal_amount)
	
	# Decrement regen by 1
	remove_status(entity, Enums.StatusEffects.REGENERATION, 1)
	
	await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))

func _process_blind(entity):
	# Blind: Placeholder behavior - currently just decrements.
	# TODO: Implement damage halving during attack phase.

	if entity.status_effects.blind <= 0:
		return
	
	# Decrement blind by 1
	remove_status(entity, Enums.StatusEffects.BLIND, 1)
	
	await CombatSpeed.create_timer(CombatSpeed.get_duration("status_effect"))

func _process_blessing(entity):
	# Blessing: Special behavior on removal (heal 3 and gain 1 damage).
	# Currently just tracks, actual removal behavior happens in remove_status.

	# Blessing doesn't proc at turn start, it procs when removed
	pass

# ===== TURN END PROCESSING =====

func process_turn_end_status_effects(entity):
	# Process status effects that trigger at turn end.
	# Currently no status effects proc at turn end (thorns removed on hit instead).

	if not entity.status_effects:
		return
	
	# Future: Add any turn-end status behaviors here
	pass

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
	
	combat_manager.add_to_combat_log_string(
		"  💢 %s has %d Thorns! %s takes reflection damage!" % [_get_entity_name(target), thorns_damage, _get_entity_name(attacker)])
	
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