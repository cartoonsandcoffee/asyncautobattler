# game_stats.gd
class_name GameStats
extends Resource

## Base stats system for players, enemies, and bosses
## Tracks both base/max values and current values where needed

signal stats_updated()

@export var damage: int = 0
@export var shield: int = 0
@export var agility: int = 0
@export var hit_points: int = 10
@export var gold: int = 0
@export var strikes: int = 1
@export var burn_damage: int = 3

# Current values that can differ from base values
var damage_current: int = 0
var shield_current: int = 0
var agility_current: int = 0
var hit_points_current: int = 10
var strikes_current: int = 1
var burn_damage_current: int = 3

var combat_temp_damage: int = 0

var refresh_cost: int = 1

func _init():
	# Initialize current values to base values
	reset_to_base_values()

func reset_to_base_values():
	# Reset current values to their base values
	damage_current = damage
	shield_current = shield
	agility_current = agility
	#hit_points_current = hit_points   # -- HP shouldn't be maxed for combat... need to do this better
	strikes_current = strikes
	burn_damage_current = burn_damage

func reset_base_stats():
	damage = 0
	shield = 0
	agility = 0
	hit_points = 10
	strikes = 1
	burn_damage = 3

func reset_stat_to_base(_stat: Enums.Stats):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points_current = hit_points
		Enums.Stats.DAMAGE:
			damage_current = damage
		Enums.Stats.SHIELD:
			shield_current = shield
		Enums.Stats.AGILITY:
			agility_current = agility
		Enums.Stats.STRIKES:
			strikes_current = strikes
		Enums.Stats.BURN_DAMAGE:
			burn_damage_current = burn_damage			
	stats_updated.emit()

func reset_stats_after_combat():
	damage_current = damage
	shield_current = shield
	agility_current = agility
	strikes_current = strikes
	burn_damage_current = burn_damage
	
	reset_combat_temp_modifiers()
	stats_updated.emit()

func reset_combat_temp_modifiers():
	combat_temp_damage = 0


func modify_combat_temp_stat(stat: Enums.Stats, amount: int):
	# Modify combat-duration temp stat and emit signal.
	match stat:
		Enums.Stats.DAMAGE:
			combat_temp_damage += amount
		_:
			push_warning("Attempted to modify combat_temp for non-output stat: %s" % stat)
	
	stats_updated.emit()


func decrease_stat(_stat: Enums.Stats, value: int):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points_current -= value
		Enums.Stats.DAMAGE:
			damage_current -= value
		Enums.Stats.SHIELD:
			shield_current -= value
		Enums.Stats.AGILITY:
			agility_current -= value
		Enums.Stats.STRIKES:
			strikes_current -= value
		Enums.Stats.BURN_DAMAGE:
			burn_damage_current -= value			
		Enums.Stats.GOLD:
			gold -= value
	stats_updated.emit()

func increase_stat(_stat: Enums.Stats, value: int):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points_current += value
		Enums.Stats.DAMAGE:
			damage_current += value
		Enums.Stats.SHIELD:
			shield_current += value	
		Enums.Stats.AGILITY:
			agility_current += value	
		Enums.Stats.STRIKES:
			strikes_current += value
		Enums.Stats.BURN_DAMAGE:
			burn_damage_current += value				
		Enums.Stats.GOLD:
			gold += value
	stats_updated.emit()
		
func set_stat(_stat: Enums.Stats, value: int):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points_current = value
		Enums.Stats.DAMAGE:
			damage_current = value	
		Enums.Stats.SHIELD:
			shield_current = value
		Enums.Stats.AGILITY:
			agility_current = value
		Enums.Stats.STRIKES:
			strikes_current = value
		Enums.Stats.BURN_DAMAGE:
			burn_damage_current = value				
		Enums.Stats.GOLD:
			gold = value
	
	stats_updated.emit()

func set_base_stat(_stat: Enums.Stats, value: int):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points = value
		Enums.Stats.DAMAGE:
			damage = value	
		Enums.Stats.SHIELD:
			shield = value
		Enums.Stats.AGILITY:
			agility = value
		Enums.Stats.STRIKES:
			strikes = value
		Enums.Stats.BURN_DAMAGE:
			burn_damage = value				
		Enums.Stats.GOLD:
			gold = value
	
	stats_updated.emit()

func increase_base_stat(_stat: Enums.Stats, value: int):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points += value
		Enums.Stats.DAMAGE:
			damage += value
		Enums.Stats.SHIELD:
			shield += value	
		Enums.Stats.AGILITY:
			agility += value	
		Enums.Stats.STRIKES:
			strikes += value
		Enums.Stats.BURN_DAMAGE:
			burn_damage += value			
	stats_updated.emit()

func decrease_base_stat(_stat: Enums.Stats, value: int):
	match _stat:
		Enums.Stats.HITPOINTS:
			hit_points -= value
		Enums.Stats.DAMAGE:
			damage -= value
		Enums.Stats.SHIELD:
			shield -= value	
		Enums.Stats.AGILITY:
			agility -= value	
		Enums.Stats.STRIKES:
			strikes -= value
		Enums.Stats.BURN_DAMAGE:
			burn_damage -= value				
	stats_updated.emit()	

# Universal stat modification function with clamping and stat type support
func modify_stat(stat: Enums.Stats, amount: int, stat_type: Enums.StatType = Enums.StatType.CURRENT, emit_signal: bool = true):
	# Universal stat modification function.
	# - Handles both CURRENT and BASE stat types
	# - Automatically clamps values to valid ranges
	# - Optionally emits stats_updated signal
	
	# This is the function that CombatStatHandler should call to ensure
	# both GameStats.stats_updated and CombatManager.stat_changed signals fire.
	
	match stat:
		Enums.Stats.HITPOINTS:
			if stat_type == Enums.StatType.BASE:
				hit_points += amount
				# Ensure current doesn't exceed new max
				hit_points_current = mini(hit_points_current, hit_points)
			elif stat_type == Enums.StatType.MISSING:
				hit_points_current -= amount
				hit_points_current = clampi(hit_points_current, 1, hit_points)	# JDM: Modify "Missing" stat to remove the value (can't be less than 1 HP,  can't kill yourself)
			else:
				hit_points_current += amount
				# Clamp to valid range [0, max]
				hit_points_current = clampi(hit_points_current, 0, hit_points)
		
		Enums.Stats.SHIELD:
			if stat_type == Enums.StatType.BASE:
				shield += amount
				shield_current = mini(shield_current, shield)
			elif stat_type == Enums.StatType.MISSING:
				shield_current -= amount
				shield_current = maxi(shield_current, 0)
			else:
				shield_current += amount
				# Shield can't go negative
				shield_current = maxi(shield_current, 0)
		
		Enums.Stats.DAMAGE:
			if stat_type == Enums.StatType.BASE:
				damage += amount
			else:
				damage_current += amount
				damage_current = maxi(damage_current, 0)
		
		Enums.Stats.AGILITY:
			if stat_type == Enums.StatType.BASE:
				agility += amount
			else:
				agility_current += amount
				# Agility can be negative theoretically, but let's floor at 0
				agility_current = maxi(agility_current, 0)
		
		Enums.Stats.STRIKES:
			if stat_type == Enums.StatType.BASE:
				strikes += amount
			else:
				strikes_current += amount
			# Minimum 1 strike
			strikes = maxi(strikes, 1)
			strikes_current = maxi(strikes_current, 1)
		
		Enums.Stats.BURN_DAMAGE:
			if stat_type == Enums.StatType.BASE:
				burn_damage += amount
			else:
				burn_damage_current += amount
				burn_damage_current = maxi(burn_damage_current, 0)
		
		Enums.Stats.GOLD:
			gold += amount
			gold = maxi(gold, 0)  # Can't have negative gold
	
	# Emit signal if requested
	if emit_signal:
		stats_updated.emit()
