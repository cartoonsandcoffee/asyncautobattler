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

# Current values that can differ from base values
var damage_current: int = 0
var shield_current: int = 0
var agility_current: int = 0
var hit_points_current: int = 10
var strikes_current: int = 1

var burn_damage: int = 3
var burn_damage_current: int = 3

var refresh_cost: int = 1

func _init():
	# Initialize current values to base values
	reset_to_base_values()

func reset_to_base_values():
	"""Reset current values to their base values"""
	damage_current = damage
	shield_current = shield
	agility_current = agility
	#hit_points_current = hit_points   # -- HP shouldn't be maxed for combat... need to do this better
	strikes_current = strikes

func reset_base_stats():
	damage = 0
	shield = 0
	agility = 0
	hit_points = 10
	strikes = 1

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
	stats_updated.emit()

func reset_stats_after_combat():
	damage_current = damage
	shield_current = shield
	agility_current = agility
	strikes_current = strikes
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
	stats_updated.emit()	