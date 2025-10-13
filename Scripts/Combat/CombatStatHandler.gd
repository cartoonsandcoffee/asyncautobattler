class_name CombatStatHandler
extends Node

## Centralized stat management system
## ALL stat changes must go through change_stat() to ensure triggers fire correctly

# Signals for stat changes
signal stat_changed(entity, stat: Enums.Stats, old_value: int, new_value: int)
signal stat_gain_triggered(entity, stat: Enums.Stats, amount: int)
signal stat_loss_triggered(entity, stat: Enums.Stats, amount: int)
signal wounded_triggered(entity)
signal exposed_triggered(entity)
signal one_hitpoint_left_triggered(entity)
signal death_triggered(entity)

var combat_manager

func _init(manager):
	combat_manager = manager

# ===== MAIN ENTRY POINT =====

func change_stat(entity, stat: Enums.Stats, amount: int, _stat_type: Enums.StatType = Enums.StatType.CURRENT):
	# -- SINGLE SOURCE OF TRUTH for all stat changes.
	
	# This function:
	# 1. Applies the stat change to the entity
	# 2. Emits stat_changed signal
	# 3. Checks for and triggers ON_STAT_GAIN/LOSS items
	# 4. Checks for WOUNDED threshold (50% HP)
	# 5. Checks for EXPOSED threshold (0 shield)
	# 6. Checks for ONE_HITPOINT_LEFT threshold
	# 7. Checks for death (0 HP)
	
	# Use this for EVERYTHING that changes stats.

	var old_value = get_stat_value(entity, stat, _stat_type)
	
	# Apply the change
	modify_stat(entity, stat, amount, _stat_type)
	
	var new_value = get_stat_value(entity, stat, _stat_type)
	
	# Emit the stat_changed signal
	stat_changed.emit(entity, stat, old_value, new_value)
	
	# Log the change
	_log_stat_change(entity, stat, old_value, new_value)
	
	# Determine if this was a gain or loss
	var delta = new_value - old_value
	
	if delta > 0:
		# Stat increased - trigger ON_STAT_GAIN items
		stat_gain_triggered.emit(entity, stat, delta)
	elif delta < 0:
		# Stat decreased - trigger ON_STAT_LOSS items
		stat_loss_triggered.emit(entity, stat, abs(delta))
	
	# Check for special thresholds
	await _check_thresholds(entity, stat, old_value, new_value)

# ===== STAT MODIFICATION =====

func modify_stat(entity, stat: Enums.Stats, amount: int, stat_type: Enums.StatType = Enums.StatType.CURRENT):
	# Directly modify a stat value without triggering item effects.
	# Used internally by change_stat() and for special cases.
	
	# stat_type:
	# - CURRENT: Modify current value (default)
	# - BASE: Modify base value (for persistent effects)

	match stat:
		Enums.Stats.HITPOINTS:
			if stat_type == Enums.StatType.BASE:
				entity.stats.hit_points += amount
				# Also update current if it would exceed new max
				entity.stats.hit_points_current = mini(entity.stats.hit_points_current, entity.stats.hit_points)
			else:
				entity.stats.hit_points_current += amount
				# Clamp to valid range
				entity.stats.hit_points_current = clampi(entity.stats.hit_points_current, 0, entity.stats.hit_points)
		
		Enums.Stats.SHIELD:
			if stat_type == Enums.StatType.BASE:
				entity.stats.shield += amount
				entity.stats.shield_current = mini(entity.stats.shield_current, entity.stats.shield)
			else:
				entity.stats.shield_current += amount
				entity.stats.shield_current = maxi(entity.stats.shield_current, 0)  # Can't go negative
		
		Enums.Stats.DAMAGE:
			if stat_type == Enums.StatType.BASE:
				entity.stats.damage += amount
			else:
				entity.stats.damage_current += amount
				entity.stats.damage_current = maxi(entity.stats.damage_current, 0)
		
		Enums.Stats.AGILITY:
			if stat_type == Enums.StatType.BASE:
				entity.stats.agility += amount
			else:
				entity.stats.agility_current += amount
		
		Enums.Stats.STRIKES:
			# Strikes don't have base/current distinction
			entity.stats.strikes += amount
			entity.stats.strikes = maxi(entity.stats.strikes, 1)  # Minimum 1 strike
		
		Enums.Stats.GOLD:
			entity.stats.gold += amount
			entity.stats.gold = maxi(entity.stats.gold, 0)

# ===== STAT GETTERS =====

func get_stat_value(entity, stat: Enums.Stats, stat_type: Enums.StatType = Enums.StatType.CURRENT) -> int:
	# Get a stat value based on type:
	# - CURRENT: Current value during combat
	# - BASE: Base value (max HP, base damage, etc.)
	# - MISSING: Difference between BASE and CURRENT (for HP/Shield)

	match stat:
		Enums.Stats.HITPOINTS:
			match stat_type:
				Enums.StatType.CURRENT:
					return entity.stats.hit_points_current
				Enums.StatType.BASE:
					return entity.stats.hit_points
				Enums.StatType.MISSING:
					return entity.stats.hit_points - entity.stats.hit_points_current
		
		Enums.Stats.SHIELD:
			match stat_type:
				Enums.StatType.CURRENT:
					return entity.stats.shield_current
				Enums.StatType.BASE:
					return entity.stats.shield
				Enums.StatType.MISSING:
					return entity.stats.shield - entity.stats.shield_current
		
		Enums.Stats.DAMAGE:
			match stat_type:
				Enums.StatType.CURRENT:
					return entity.stats.damage_current
				Enums.StatType.BASE:
					return entity.stats.damage
				Enums.StatType.MISSING:
					return 0  # Damage doesn't have "missing"
		
		Enums.Stats.AGILITY:
			match stat_type:
				Enums.StatType.CURRENT:
					return entity.stats.agility_current
				Enums.StatType.BASE:
					return entity.stats.agility
				Enums.StatType.MISSING:
					return 0
		
		Enums.Stats.STRIKES:
			return entity.stats.strikes
		
		Enums.Stats.GOLD:
			return entity.stats.gold
	
	return 0

# ===== THRESHOLD CHECKS =====

func _check_thresholds(entity, stat: Enums.Stats, old_value: int, new_value: int):
	# Check for special thresholds and emit appropriate signals.
	
	# Check for WOUNDED (50% HP)
	if stat == Enums.Stats.HITPOINTS:
		var max_hp = entity.stats.hit_points
		var wounded_threshold = max_hp / 2
		
		# Crossed the 50% threshold going down?
		if old_value > wounded_threshold and new_value <= wounded_threshold:
			if not _is_wounded_triggered(entity):
				_mark_wounded_triggered(entity, true)
				wounded_triggered.emit(entity)
		
		# Check for ONE_HITPOINT_LEFT
		if new_value == 1 and old_value > 1:
			one_hitpoint_left_triggered.emit(entity)
		
		# Check for death
		if new_value <= 0:
			death_triggered.emit(entity)
	
	# Check for EXPOSED (0 shield)
	if stat == Enums.Stats.SHIELD:
		if old_value > 0 and new_value == 0:
			if not _is_exposed_triggered(entity):
				_mark_exposed_triggered(entity, true)
				exposed_triggered.emit(entity)

# ===== HELPER FUNCTIONS =====

func _log_stat_change(entity, stat: Enums.Stats, old_value: int, new_value: int):
	"""Log stat changes to combat log."""
	var entity_name = _get_entity_name(entity)
	var stat_name = Enums.get_stat_string(stat)
	var change = new_value - old_value
	var change_str = ("+" + str(change)) if change > 0 else str(change)
	
	var log_msg = "    %s %s: %d → %d (%s)" % [entity_name, stat_name, old_value, new_value, change_str]
	combat_manager.add_to_combat_log_string(log_msg)

func _get_entity_name(entity) -> String:
	"""Get the display name of an entity."""
	if entity == combat_manager.player_entity:
		return "Player"
	elif entity == combat_manager.enemy_entity:
		if entity is Enemy:
			return entity.enemy_name
		return "Enemy"
	return "Unknown"

# ===== EXPOSED/WOUNDED TRACKING =====

func _is_exposed_triggered(entity) -> bool:
	# Check if entity has already triggered EXPOSED this combat.
	if entity == combat_manager.player_entity:
		return combat_manager.player_exposed_triggered
	else:
		return combat_manager.enemy_exposed_triggered

func _mark_exposed_triggered(entity, value: bool):
	# Mark entity as having triggered EXPOSED.
	if entity == combat_manager.player_entity:
		combat_manager.player_exposed_triggered = value
	else:
		combat_manager.enemy_exposed_triggered = value

func _is_wounded_triggered(entity) -> bool:
	# Check if entity has already triggered WOUNDED this combat.
	if entity == combat_manager.player_entity:
		return combat_manager.player_wounded_triggered
	else:
		return combat_manager.enemy_wounded_triggered

func _mark_wounded_triggered(entity, value: bool):
	# Mark entity as having triggered WOUNDED.
	if entity == combat_manager.player_entity:
		combat_manager.player_wounded_triggered = value
	else:
		combat_manager.enemy_wounded_triggered = value

# ===== RESET FUNCTIONS =====

func reset_combat_state():
	"""Reset all threshold triggers for a new combat."""
	combat_manager.player_exposed_triggered = false
	combat_manager.enemy_exposed_triggered = false
	combat_manager.player_wounded_triggered = false
	combat_manager.enemy_wounded_triggered = false