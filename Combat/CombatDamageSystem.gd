class_name CombatDamageSystem
extends Node

## Unified damage and healing system
## ALL damage and healing goes through this system to ensure consistency

signal damage_dealt(target, amount, source)
signal healing_applied(target, amount)

var combat_manager
var stat_handler: CombatStatHandler
var status_handler: CombatStatusHandler
var game_colors: GameColors

func _init(manager, stat_handler_ref: CombatStatHandler, status_handler_ref: CombatStatusHandler):
	combat_manager = manager
	stat_handler = stat_handler_ref
	status_handler = status_handler_ref
	game_colors = GameColors.new()

# ===== DAMAGE APPLICATION =====

func apply_damage(target, amount: int, source, damage_type: String) -> int:
	# --- SINGLE SOURCE OF TRUTH for all damage in combat.
	
	# Damage flow:
	# 1. Apply to shield first (if any)
	# 2. Apply remaining to HP
	# 3. Check for thorns reflection
	# 4. Create damage visuals
	# 5. Emit signals
	
	# Returns: Total damage dealt
	# damage_type: "attack", "poison", "burn", "acid", "thorns", "item"

	if amount <= 0:
		return 0
	
	var total_damage_dealt = 0
	var remaining_damage = amount
	
	# STEP 1: Apply to shield first 
	if target.stats.shield_current > 0:
		var shield_damage = mini(target.stats.shield_current, remaining_damage)
		
		# Apply shield damage
		stat_handler.change_stat(target, Enums.Stats.SHIELD, -shield_damage)
		
		# Create shield damage visual
		var shield_stat = Enums.Stats.SHIELD
		if target.stats.shield_current == 0:
			shield_stat = Enums.Stats.EXPOSED
		
		await _create_damage_visual(target, shield_damage, shield_stat, source, damage_type)
		
		total_damage_dealt += shield_damage
		remaining_damage -= shield_damage
	
	# STEP 2: Apply remaining damage to HP
	if remaining_damage > 0:
		var hp_damage = remaining_damage
		
		# Apply HP damage
		stat_handler.change_stat(target, Enums.Stats.HITPOINTS, -hp_damage)
		
		# Create HP damage visual
		var hp_stat = Enums.Stats.HITPOINTS
		# Check if this brought them to wounded threshold
		var hp_percent = float(target.stats.hit_points_current) / float(target.stats.hit_points)
		if hp_percent <= 0.5:
			hp_stat = Enums.Stats.WOUNDED
		
		await _create_damage_visual(target, hp_damage, hp_stat, source, damage_type)
		
		total_damage_dealt += hp_damage
	
	# STEP 3: Process thorns reflection (if source exists and target has thorns)
	if source and damage_type == "attack":
		await status_handler.process_thorns_reflection(source, target)
	
	# Emit signal
	damage_dealt.emit(target, total_damage_dealt, source)
	
	return total_damage_dealt

# ===== HEALING =====

func heal_entity(entity, amount: int):
	# Heal an entity's HP.
	# Automatically clamps to max HP.

	if amount <= 0:
		return
	
	var old_hp = entity.stats.hit_points_current
	
	# Heal through stat handler (it handles clamping)
	stat_handler.change_stat(entity, Enums.Stats.HITPOINTS, amount)
	
	var actual_healing = entity.stats.hit_points_current - old_hp
	
	if actual_healing > 0:
		# Create healing visual
		await _create_damage_visual(entity, actual_healing, Enums.Stats.HITPOINTS, null, "heal")
		
		# Emit signal
		healing_applied.emit(entity, actual_healing)
		
		combat_manager.add_to_combat_log_string("  %s heals for %d HP" % [_get_entity_name(entity), actual_healing], Color.GREEN)
	
	# Handle overheal for special mechanics
	var overheal = amount - actual_healing
	if overheal > 0 and entity.status_effects:
		entity.status_effects.overheal_triggered.emit(overheal)

# ===== DAMAGE VISUALS =====

func _create_damage_visual(target, amount: int, damage_stat: Enums.Stats, source, damage_type: String):
	# Create visual feedback for damage/healing.
	# Routes through AnimationManager to create damage indicators.
	
	# Prepare visual info based on damage type
	var visual_info = _get_visual_info_for_damage_type(damage_type, source)
	
	# Send to animation manager
	combat_manager.animation_manager.play_damage_indicator(target, amount, damage_stat, visual_info)
	
	# Small delay for visual feedback
	await CombatSpeed.create_timer(CombatSpeed.get_duration("item_proc") * 0.3)

func _get_visual_info_for_damage_type(damage_type: String, source) -> Dictionary:
	# Get visual information (icon, color, name) for a damage type.

	var info = {
		"icon": null,
		"color": Color.WHITE,
		"source_name": ""
	}
	
	match damage_type:
		"attack":
			if source:
				if source == combat_manager.player_entity:
					# Use weapon icon if available
					if source.inventory and source.inventory.weapon_slot:
						info.icon = source.inventory.weapon_slot.item_icon
						info.color = source.inventory.weapon_slot.item_color
						info.source_name = "Attack"
				else:
					# Enemy attack
					if source == combat_manager.enemy_entity and source is Enemy:
						info.icon = source.weapon_sprite  # Enemy weapon
						info.color = game_colors.stats.damage
					info.source_name = "Attack"
		
		"poison":
			info.icon = load("res://Resources/StatIcons/StatusIcons/status_poison.tres")
			info.color = game_colors.stats.poison
			info.source_name = "Poison"
		
		"burn":
			info.icon = load("res://Resources/StatIcons/StatusIcons/status_burn.tres")
			info.color = game_colors.stats.burn
			info.source_name = "Burn"
		
		"acid":
			info.icon = load("res://Resources/StatIcons/StatusIcons/status_acid.tres")
			info.color = game_colors.stats.acid
			info.source_name = "Acid"
		
		"thorns":
			info.icon = load("res://Resources/StatIcons/StatusIcons/status_thorns.tres")
			info.color = game_colors.stats.thorns
			info.source_name = "Thorns"
		
		"item":
			# For item damage, source should be the item
			if source is Item:
				info.icon = source.item_icon
				info.color = source.item_color
				info.source_name = source.item_name
		
		"heal", "regeneration":
			info.icon = load("res://Resources/StatIcons/icon_health.tres")
			info.color = game_colors.stats.regeneration
			info.source_name = "Heal"
	
	return info

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