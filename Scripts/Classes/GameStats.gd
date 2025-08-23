# game_stats.gd
class_name GameStats
extends Resource

## Base stats system for players, enemies, and bosses
## Tracks both base/max values and current values where needed

signal stat_changed(stat_name: String, old_value: int, new_value: int)

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

func _init():
	# Initialize current values to base values
	reset_to_base_values()

func reset_to_base_values():
	"""Reset current values to their base values"""
	damage_current = damage
	shield_current = shield
	agility_current = agility
	hit_points_current = hit_points
