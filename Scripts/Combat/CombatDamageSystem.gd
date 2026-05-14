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

func apply_damage(target, amount: int, source, damage_type: String, source_item: Item = null) -> int:
	# --- SINGLE SOURCE OF TRUTH for all damage in combat.
	
	# Damage flow:
	# 1. Apply to shield first (if any)
	# 2. Apply remaining to HP
	# 3. Create damage visuals
	# 4. Emit signals
	
	# Returns: Total damage dealt
	# damage_type: "attack", "poison", "burn", "acid", "thorns", "item"

	if amount <= 0:
		return 0

	var total_damage_dealt = 0
	var remaining_damage = amount
	var damage_events: Array[CombatEvent] = []

	# Capture threshold values at function scope
	var shield_before: int = 0
	var shield_after: int = 0
	var hp_before: int = 0
	var hp_after: int = 0
	var shield_hit: bool = false
	var hp_hit: bool = false

	# STEP 1: Shield
	if target.stats.shield_current > 0:
		shield_before = target.stats.shield_current
		var shield_damage: int = mini(target.stats.shield_current, remaining_damage)
		shield_after = shield_before - shield_damage
		var will_expose: bool = shield_after == 0
		var visual_stat = Enums.Stats.EXPOSED if will_expose else Enums.Stats.SHIELD
		var v_info = _get_visual_info_for_damage_type(damage_type, source)
		damage_events.append(CombatEvent.damage_visual(target, shield_damage, visual_stat, v_info))
		damage_events.append(CombatEvent.modify_stat(target, Enums.Stats.SHIELD, -shield_damage, Enums.StatType.CURRENT, source_item, damage_type))
		total_damage_dealt += shield_damage
		remaining_damage -= shield_damage
		shield_hit = true

	# STEP 2: HP
	if remaining_damage > 0:
		hp_before = target.stats.hit_points_current
		var hp_damage: int = remaining_damage
		hp_after = max(0, hp_before - hp_damage)
		var will_wound: bool = (float(hp_after) / float(target.stats.hit_points)) <= 0.5
		var hp_visual_stat = Enums.Stats.WOUNDED if will_wound else Enums.Stats.HITPOINTS
		var hp_v_info = _get_visual_info_for_damage_type(damage_type, source)
		damage_events.append(CombatEvent.damage_visual(target, hp_damage, hp_visual_stat, hp_v_info))
		damage_events.append(CombatEvent.modify_stat(target, Enums.Stats.HITPOINTS, -hp_damage, Enums.StatType.CURRENT, source_item, damage_type))
		total_damage_dealt += hp_damage
		hp_hit = true

	# Append threshold checks at END of batch so EXPOSED/WOUNDED fire
	# only after the full hit (shield + HP carry-through) has resolved.
	if shield_hit:
		damage_events.append(CombatEvent.check_thresholds(target, Enums.Stats.SHIELD, shield_before, shield_after))
	if hp_hit:
		damage_events.append(CombatEvent.check_thresholds(target, Enums.Stats.HITPOINTS, hp_before, hp_after))

	combat_manager.event_queue.enqueue_batch_next(damage_events)
	damage_dealt.emit(target, total_damage_dealt, source)
	return total_damage_dealt

# ===== HEALING =====

func heal_entity(entity, amount: int, source, heal_source_label: String = "Heal"):
	if amount <= 0:
		return
	var old_hp = entity.stats.hit_points_current
	var max_hp: int = entity.stats.hit_points
	var actual_healing: int = min(amount, max_hp - old_hp)
	combat_manager.event_queue.enqueue_next(CombatEvent.modify_stat(entity, Enums.Stats.HITPOINTS, amount, Enums.StatType.CURRENT, source, heal_source_label))
	
	if actual_healing > 0:
		# Emit signal
		healing_applied.emit(entity, actual_healing)
		

# ===== DAMAGE VISUALS =====
	
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
					# Enemy attack — check inventory first (PvP boss), fall back to weapon_sprite
					if "inventory" in source and source.inventory and source.inventory.weapon_slot:
						info.icon = source.inventory.weapon_slot.item_icon
						info.color = source.inventory.weapon_slot.item_color
					elif source is Enemy and source.weapon_sprite:
						info.icon = source.weapon_sprite
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
		
		"regeneration":
			info.icon = load("res://Resources/StatIcons/StatusIcons/status_regen.tres")
			info.color = game_colors.stats.regeneration
			info.source_name = "Regeneration"

		"blessing":
			info.icon = load("res://Resources/StatIcons/StatusIcons/status_blessing.tres")
			info.color = game_colors.stats.blessing
			info.source_name = "Blessing"

		"item":
			# For item damage, source should be the item
			if source is Item:
				info.icon = source.item_icon
				info.color = source.item_color
				info.source_name = source.item_name
		
		"heal":
			info.icon = load("res://Resources/StatIcons/icon_health.tres")
			info.color = game_colors.stats.regeneration
			info.source_name = "Heal"
	
	if damage_type.begins_with("Strike"):
		if source:
			if source == combat_manager.player_entity:
				if source.inventory and source.inventory.weapon_slot:
					info.icon = source.inventory.weapon_slot.item_icon
					info.color = source.inventory.weapon_slot.item_color
			else:
				if "inventory" in source and source.inventory and source.inventory.weapon_slot:
					info.icon = source.inventory.weapon_slot.item_icon
					info.color = source.inventory.weapon_slot.item_color
				elif source is Enemy and source.weapon_sprite:
					info.icon = source.weapon_sprite
					info.color = game_colors.stats.damage
			info.source_name = damage_type


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
