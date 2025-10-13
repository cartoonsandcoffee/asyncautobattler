class_name EnemyAbility
extends Resource


@export var ability_name: String = "Unknown Ability"
@export_multiline var description: String = ""

@export var rules: Array[ItemRule]	#this should make all the variables below it unnecessary.

# Runtime state
var current_countdown: int = 0
var times_triggered: int = 0
var turn_counter: int = 0

func _init():
	current_countdown = 0

func reset_for_combat():
	"""Reset runtime values for a new combat"""
	current_countdown = 0
	turn_counter = 0
	times_triggered = 0

func get_description() -> String:
	"""Generate a description of what this ability does"""
	if description != "":
		return description
	
	return ""